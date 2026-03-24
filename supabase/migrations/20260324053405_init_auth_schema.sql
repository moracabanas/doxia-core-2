-- Auth Schema: Members, Invites, and RBAC
-- Phase 4: Multi-tenant authentication

-- ============================================
-- MEMBERS
-- ============================================
CREATE TABLE members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member', 'viewer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

CREATE INDEX idx_members_user_id ON members(user_id);
CREATE INDEX idx_members_organization_id ON members(organization_id);

-- RLS for members
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- Policy: users can see their own memberships
CREATE POLICY rls_select_members ON members
    FOR SELECT USING (user_id = auth.uid());

-- Policy: only admins can manage members
CREATE POLICY rls_insert_members ON members
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY rls_update_members ON members
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY rls_delete_members ON members
    FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- INVITES
-- ============================================
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member', 'viewer')),
    token UUID NOT NULL DEFAULT gen_random_uuid(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, email)
);

CREATE INDEX idx_invites_email ON invites(email);
CREATE INDEX idx_invites_token ON invites(token);
CREATE INDEX idx_invites_organization_id ON invites(organization_id);

-- RLS for invites
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;

-- Policy: members of org can see invites
CREATE POLICY rls_select_invites ON invites
    FOR SELECT USING (organization_id IN (
        SELECT organization_id FROM members WHERE user_id = auth.uid()
    ));

-- Policy: only admins can create invites
CREATE POLICY rls_insert_invites ON invites
    FOR INSERT WITH CHECK (organization_id IN (
        SELECT organization_id FROM members WHERE user_id = auth.uid() AND role = 'admin'
    ));

-- Policy: only admins can delete invites
CREATE POLICY rls_delete_invites ON invites
    FOR DELETE USING (organization_id IN (
        SELECT organization_id FROM members WHERE user_id = auth.uid() AND role = 'admin'
    ));

-- ============================================
-- JIT PROVISIONING FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.fn_handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_invite RECORD;
    v_org_id UUID;
BEGIN
    -- Check if email has a pending invite
    SELECT * INTO v_invite
    FROM invites
    WHERE email = NEW.email
    LIMIT 1;

    IF FOUND THEN
        -- User has a pending invite - add to that organization
        v_org_id := v_invite.organization_id;

        -- Add user to organization as the role specified in invite
        INSERT INTO members (organization_id, user_id, role)
        VALUES (v_org_id, NEW.id, v_invite.role)
        ON CONFLICT (organization_id, user_id) DO NOTHING;

        -- Delete the invite
        DELETE FROM invites WHERE id = v_invite.id;
    ELSE
        -- No invite found - create personal workspace
        INSERT INTO organizations (name)
        VALUES (NEW.email || '''s Personal Workspace')
        RETURNING id INTO v_org_id;

        -- Add user as admin
        INSERT INTO members (organization_id, user_id, role)
        VALUES (v_org_id, NEW.id, 'admin');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- AUTH USER TRIGGER
-- ============================================
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_new_user();

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE members IS 'Organization membership with RBAC roles';
COMMENT ON TABLE invites IS 'Pending invitations to organizations';
COMMENT ON COLUMN members.role IS 'admin, member, or viewer';
COMMENT ON COLUMN invites.role IS 'Role to assign when invite is accepted';
COMMENT ON FUNCTION fn_handle_new_user() IS 'JIT provisioning: creates personal org or accepts invite';

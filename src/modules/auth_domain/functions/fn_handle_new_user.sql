-- JIT Provisioning Function
-- When a new user is created in auth.users, check invites or create personal org

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

-- pgTAP Tests for Auth and RLS Isolation
-- Phase 4: Verify multi-tenant isolation

BEGIN;

-- Total tests
SELECT plan(10);

-- ============================================
-- Test: Tables exist
-- ============================================
SELECT ok(
    EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'members'
    ),
    'members table should exist'
);

SELECT ok(
    EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'invites'
    ),
    'invites table should exist'
);

-- ============================================
-- Test: Members columns
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'members'
        AND column_name = 'user_id'
    ),
    'members.user_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'members'
        AND column_name = 'role'
    ),
    'members.role should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'members'
        AND column_name = 'organization_id'
    ),
    'members.organization_id should exist'
);

-- ============================================
-- Test: Invites columns
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'invites'
        AND column_name = 'email'
    ),
    'invites.email should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'invites'
        AND column_name = 'token'
    ),
    'invites.token should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'invites'
        AND column_name = 'expires_at'
    ),
    'invites.expires_at should exist'
);

-- ============================================
-- Test: RLS enabled on members and invites
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_tables
        WHERE tablename = 'members'
        AND rowsecurity = true
    ),
    'RLS should be enabled on members'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_tables
        WHERE tablename = 'invites'
        AND rowsecurity = true
    ),
    'RLS should be enabled on invites'
);

-- ============================================
-- Complete
-- ============================================
SELECT * FROM finish();

ROLLBACK;

-- Trigger: trg_on_auth_user_created
-- Fires AFTER INSERT on auth.users to handle JIT provisioning

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_new_user();

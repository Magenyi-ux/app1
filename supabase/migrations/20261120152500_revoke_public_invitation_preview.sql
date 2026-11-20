-- Invitation links in onboarding are account-first; do not expose preview data to anonymous callers.
revoke execute on function public.preview_journal_invitation(text) from public, anon;
grant execute on function public.preview_journal_invitation(text) to authenticated;

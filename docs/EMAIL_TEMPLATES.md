# OurJournal — Supabase Auth Email Templates

These branded templates are prepared for **Supabase Dashboard → Authentication → Email Templates**. The connected Supabase management tools available to this workflow do not expose the Auth email-template settings API, so the templates are committed here for applying in that dashboard. Do not claim they are live until saved and tested there.

Use the existing configured SMTP sender. Keep Supabase's confirmation/recovery links and variables intact.

## Confirm signup
**Subject:** Confirm your OurJournal account

```html
<div style="margin:0;background:#f4edf8;padding:32px 12px;font-family:Arial,sans-serif;color:#211631">
  <div style="max-width:520px;margin:auto;background:#fffaff;border:1px solid #e5d8ef;border-radius:22px;padding:32px">
    <div style="font-size:13px;letter-spacing:2px;color:#7540b6;font-weight:bold">OURJOURNAL</div>
    <h1 style="font-size:28px;line-height:1.2">Confirm your email</h1>
    <p style="font-size:16px;line-height:1.7">One small step before you begin writing, understanding, and growing together.</p>
    <p><a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#7540b6;color:#fff;text-decoration:none;padding:14px 24px;border-radius:999px;font-weight:bold">Confirm email address</a></p>
    <p style="font-size:13px;line-height:1.6;color:#766b84">If you did not create an OurJournal account, you can ignore this email.</p>
  </div>
</div>
```

## Reset password
**Subject:** Reset your OurJournal password

```html
<div style="margin:0;background:#f4edf8;padding:32px 12px;font-family:Arial,sans-serif;color:#211631">
  <div style="max-width:520px;margin:auto;background:#fffaff;border:1px solid #e5d8ef;border-radius:22px;padding:32px">
    <div style="font-size:13px;letter-spacing:2px;color:#7540b6;font-weight:bold">OURJOURNAL</div>
    <h1 style="font-size:28px;line-height:1.2">Choose a new password</h1>
    <p style="font-size:16px;line-height:1.7">We received a request to reset your OurJournal password. Use the button below to continue.</p>
    <p><a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#7540b6;color:#fff;text-decoration:none;padding:14px 24px;border-radius:999px;font-weight:bold">Reset password</a></p>
    <p style="font-size:13px;line-height:1.6;color:#766b84">If you did not request this, ignore this email. Your password will not change unless you complete the reset.</p>
  </div>
</div>
```

## Magic link
**Subject:** Your OurJournal sign-in link

```html
<div style="margin:0;background:#f4edf8;padding:32px 12px;font-family:Arial,sans-serif;color:#211631">
  <div style="max-width:520px;margin:auto;background:#fffaff;border:1px solid #e5d8ef;border-radius:22px;padding:32px">
    <div style="font-size:13px;letter-spacing:2px;color:#7540b6;font-weight:bold">OURJOURNAL</div>
    <h1 style="font-size:28px">Sign in securely</h1>
    <p style="font-size:16px;line-height:1.7">Use this one-time link to sign in to OurJournal.</p>
    <p><a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#7540b6;color:#fff;text-decoration:none;padding:14px 24px;border-radius:999px;font-weight:bold">Sign in to OurJournal</a></p>
    <p style="font-size:13px;color:#766b84">If you did not request this email, you can ignore it.</p>
  </div>
</div>
```

## Invite user
**Subject:** You're invited to OurJournal

```html
<div style="margin:0;background:#f4edf8;padding:32px 12px;font-family:Arial,sans-serif;color:#211631">
  <div style="max-width:520px;margin:auto;background:#fffaff;border:1px solid #e5d8ef;border-radius:22px;padding:32px">
    <div style="font-size:13px;letter-spacing:2px;color:#7540b6;font-weight:bold">OURJOURNAL</div>
    <h1 style="font-size:28px">An invitation to write together</h1>
    <p style="font-size:16px;line-height:1.7">You have been invited to join OurJournal. Create or sign in to your account to continue.</p>
    <p><a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#7540b6;color:#fff;text-decoration:none;padding:14px 24px;border-radius:999px;font-weight:bold">Accept invitation</a></p>
    <p style="font-size:13px;color:#766b84">Only accept invitations you were expecting.</p>
  </div>
</div>
```

## Security checklist
- In Authentication → URL Configuration, allow only the exact production origin and required password-recovery callback.
- In each email template, retain Supabase's provided confirmation URL variable; never hard-code an auth token.
- Use SMTP and test confirmation and recovery emails with a new test account.
- Journal invitation links are separate from Supabase Auth invites: they are random 256-bit tokens, stored only as SHA-256 hashes, expire in 20 minutes, and can be accepted once.

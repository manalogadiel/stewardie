# Stewardie verification email rollout

Status: app verification UI is implemented. Custom email delivery is not deployed; an owned domain and approved sender are still needed. An app change cannot guarantee inbox placement.

The user confirmed they currently have Firebase only, with no email provider or owned sender domain. A branded HTML/plain-text template is prepared in `templates/email/verify-email.html` and `templates/email/verify-email.txt`, with an asset-embedded local preview in `build/review/verify-email-preview.html`. Live custom sending and Flutter send-path changes are intentionally pending provider/domain setup. The browser refused the local `file:` preview protocol, so visual rendering and email-client checks are not claimed.

## Brevo setup — October 4, 2026

The user created a free Brevo account. Its existing sender was verified; changed only its display name from Gadiel to **Stewardie**, retained the email address, and confirmed it still shows **Verified**. Evidence: `build/review/brevo-sender-ready.png`. Brevo warns about using a free email provider; authenticated sender-address replacement can support this initial setup, but inbox placement is not guaranteed.

The account dashboard requires phone verification before sending messages. No API keys exist yet. Left the browser on **Settings → SMTP & API → API keys & MCP** for the user to generate a regular key named `Stewardie verification`. Creating/entering new credentials is a user handoff under the browser confirmation policy. Do not put the key in Flutter, chat, screenshots or Git; eventual storage destination is the existing Supabase project's server secrets under `BREVO_API_KEY`.

Pending: user phone verification/API key setup, protected custom-verification gateway with server-side recipient selection and resend limits, public approved email artwork, actual Gmail/Outlook delivery checks, and switching both initial-send/resend app paths together. No Brevo message was sent and no app delivery path was changed in this setup pass. Existing Firebase verification continues.

## Protected integration deployed — October 4, 2026

The user saved `BREVO_API_KEY` themselves; only its name/digest was inspected. Saved the existing verified sender as `BREVO_SENDER_EMAIL`. Deployed migration 008 and a standalone `verification-email` gateway bundled from `index.ts`, `policy.mjs` and `branding.mjs`. The public asset routes serve only resized approved logo/mascot art; no private photos or account information. The send route verifies Firebase JWT signature/issuer/audience, checks the current account and token revocation timestamp, and generates a Firebase verification link for that account's actual email. It never accepts a client recipient or redirect and does not log links/tokens/provider responses.

Limits: a 60-second account cooldown, 10 attempts per account per UTC day, 280 project attempts per UTC day, and one last-operation receipt per account. Duplicate operations do not resend; ambiguous timeouts remain pending. Tables are private with service-only RPC access. No new authentication accounts or real verification emails were created for testing.

Updated all four initial/resend app paths to use the shared sender. `USE_BREVO_VERIFICATION` remains false by default until activation. A known disabled/uninstalled endpoint falls back to Firebase; timeouts/provider failures never automatically send a second Firebase email. Local emulator sends stay on Firebase.

Activation is still gated: the gateway's legacy Supabase JWT setting is ON (Firebase callers need the deployed internal Firebase checks instead), and Brevo API IP blocking is Activated with zero authorized IPs. Explicit confirmations for both changes were requested and have not yet been received. Supabase has no static Edge Function egress IP; a stable proxy is an alternative if retaining Brevo IP restrictions. `STEW_BREVO_ENABLED` is not set. Existing Firebase sending stays active until these gates are resolved.

Validation: three policy tests, a PGlite quota/privacy test, three Flutter fallback/timeout/coalescing tests, and 18 onboarding regression tests passed. Dart analysis found one formatting lint which was fixed; the shared sender subsequently analyzed clean. Dashboard deployment source was compared with the generated bundle before deploying. Live actual delivery, Firebase Admin link generation and Gmail/Outlook rendering are not yet verified. Screenshots: `build/review/verification-gateway-deployed.png`, `brevo-server-configured.png`, `brevo-ip-blocking-review.png`.

References: [Firebase custom verification links](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/sendOobCode), [Brevo transactional email API](https://developers.brevo.com/docs/send-a-transactional-email), [Supabase egress IP limitation](https://supabase.com/docs/guides/troubleshooting/why-supabase-edge-functions-cannot-provide-static-egress-ips-for-whitelisting-3d78b0).

## Live configuration check — October 4, 2026

The signed-in Firebase console allowed editing the sender and subject, but rejected Save with: **“Email template updates are currently unavailable for this project.”** The displayed template still has no sender name and the original subject `Verify your email for %APP_NAME%`. No template change was applied. The console links to Firebase support for this restriction. Evidence: `build/review/verification-email-branding.png`.

Retain the existing verification link and sender until this project restriction is resolved. An owned domain/provider is also required for the full custom mascot email; neither has been supplied. Do not describe email branding or spam prevention as deployed.

## Existing Firebase sender

In Firebase Authentication → Templates → Email address verification, set:

- Sender name: **Stewardie**
- Subject: **Verify your email for Stewardie**
- App name: **Stewardie** (check public project/app settings).
- Keep the existing working Firebase action URL until its replacement is deployed and tested.

Firebase restricts editing the stock verification message. It does not support adding a complete custom mascot email simply by changing Flutter widgets. Do not paste arbitrary HTML into unsupported fields.

## Custom sender, when a domain is available

1. Confirm domain ownership and the permitted sender address. No new paid service is required by this document.
2. Use Firebase's custom Authentication email-domain configuration. Publish exactly the DNS records shown for this project; verify them and apply the verified domain. Check SPF/DKIM alignment and introduce DMARC monitoring before an enforcement policy.
3. For a fully branded message, generate the verification link on a trusted server with Firebase Admin and send it through the approved transactional provider. Never generate verification tokens in Flutter or accept `verified=true` as proof.
4. Use this copy in the custom template: **“One small step, a little more together. Verify your email to finish setting up Stewardie and safely join your spaces.”** Button: **“Verify my email”**. Footer: **“If you didn’t create a Stewardie account, you can ignore this email. Your address won’t be verified unless you use this link.”** Include the approved Stewardie logo and existing email-verification mascot, with text usable when images are blocked.
5. Permit only HTTPS action/continue destinations owned by the project. Do not use an open redirect, tracking link or shortened URL. Keep password-reset and email-change actions working if customizing the shared handler.
6. Test a real newly requested email on Gmail and Outlook: recipient, headers, verified sender, desktop/mobile link, expiry, reuse, account switch, resend cooldown, and Firebase token refresh after verification. Record observed inbox/spam placement; do not promise spam prevention.

Official references: [Firebase email customization limits](https://support.google.com/firebase/answer/7000714), [custom Authentication email domains](https://firebase.google.com/docs/auth/email-custom-domain), [Admin-generated action links](https://firebase.google.com/docs/auth/admin/email-action-links), [custom action handlers](https://firebase.google.com/docs/auth/custom-email-handler).

Until the domain/sender is configured, retain the working Firebase sender, branded in-app verification screen, resend control and spam-folder guidance.

## Brevo activated — October 4, 2026

This update supersedes the earlier Firebase-only rollout status. A verified Brevo sender can be used without an owned domain; inbox placement remains unproven.

- User saved `BREVO_API_KEY`; its value was never copied into the client or displayed by the agent. `BREVO_SENDER_EMAIL` is configured on the server.
- User disabled legacy JWT verification for `verification-email` and disabled Brevo API-key IP blocking. Both settings were inspected and confirmed.
- Saved `STEW_BREVO_ENABLED=true` on Supabase. The Flutter shared sender now defaults to custom delivery for ordinary `flutter run`; emulator sending retains Firebase.
- The gateway verifies Firebase tokens and the current account, selects the recipient on the server, and uses bounded resend quotas and operation deduplication. API keys stay server-only.
- Live checks: unauthenticated POST returned **401 / Sign in again**, public logo returned **200 / image/png**. These checks did not send email.
- Real authenticated delivery, verification-link completion and inbox/spam placement still require a device test with an unverified account. Do not claim these passed.
- Rollback: set `STEW_BREVO_ENABLED=false`; the client's known-disabled response falls back to Firebase. Ambiguous provider/network failures do not fall back and double-send.

Activation evidence: `build/review/brevo-activated.png`.

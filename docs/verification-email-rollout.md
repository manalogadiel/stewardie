# Stewardie verification email rollout

Status: app verification UI is implemented. Custom email delivery is not deployed; an owned domain and approved sender are still needed. An app change cannot guarantee inbox placement.

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

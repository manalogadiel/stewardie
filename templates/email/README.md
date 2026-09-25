# Stewardie Email Templates

This directory contains branded HTML email templates tailored to Stewardie's **Soft Pop** design system (pastel clay aesthetics, `#FAF9F6` canvas, `#244BFF` primary blue, and mascot illustration).

---

## 1. `verify_email.html`
Used for Firebase Authentication email verification.

### How to use in Firebase Console:
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Select the **`stewardie`** project.
3. Navigate to **Authentication** > **Templates** > **Email address verification**.
4. Click the edit icon (**✏️**).
5. Switch to **HTML mode** or paste the content from `verify_email.html`.
6. Confirm the template uses the `%LINK%` and `%APP_NAME%` placeholders.
7. Save changes.

### Custom SMTP / Transactional Services (Resend, SendGrid, Postmark):
You can also feed `verify_email.html` directly into your email provider's template engine, replacing `%LINK%` with your dynamic action URL.

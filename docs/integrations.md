# Provider Integrations

Smart Helpdesk keeps provider secrets in environment variables only. Frontend APIs must never return Facebook, Mailgun, SendGrid, or Firebase credentials.

## Facebook Messenger

Required environment variables:

- `FACEBOOK_VERIFY_TOKEN`
- `FACEBOOK_APP_SECRET`
- `FACEBOOK_PAGE_ACCESS_TOKEN`

Provider setup:

1. Create or select a Meta app.
2. Add Messenger and connect the Facebook Page.
3. Configure the webhook callback URL: `https://<api-host>/webhooks/facebook`.
4. Use `FACEBOOK_VERIFY_TOKEN` as the webhook verify token.
5. Subscribe to page message events.
6. Store the Page Access Token in `FACEBOOK_PAGE_ACCESS_TOKEN`.

Runtime behavior:

- `GET /webhooks/facebook` handles Meta webhook verification.
- `POST /webhooks/facebook` parses Graph API message events.
- `X-Hub-Signature-256` is verified when `FACEBOOK_APP_SECRET` is configured.
- Human replies are sent through the Facebook Send API when `FACEBOOK_PAGE_ACCESS_TOKEN` is configured; otherwise local development uses a mock sender.

## Email

Supported providers:

- Mailgun
- SendGrid

Shared inbound URL:

- `POST https://<api-host>/webhooks/email?provider=mailgun`
- `POST https://<api-host>/webhooks/email?provider=sendgrid`

### Mailgun

Required environment variables:

- `MAILGUN_API_KEY`
- `MAILGUN_DOMAIN`
- `MAILGUN_WEBHOOK_SIGNING_KEY`
- `MAILGUN_FROM_EMAIL` optional
- `OUTBOUND_EMAIL_PROVIDER=mailgun`

Setup:

1. Configure an inbound route that forwards to `/webhooks/email?provider=mailgun`.
2. Store the webhook signing key in `MAILGUN_WEBHOOK_SIGNING_KEY`.
3. Store outbound API credentials in `MAILGUN_API_KEY` and `MAILGUN_DOMAIN`.

### SendGrid

Required environment variables:

- `SENDGRID_API_KEY`
- `SENDGRID_WEBHOOK_PUBLIC_KEY` optional boundary for signature enforcement
- `SENDGRID_FROM_EMAIL` optional
- `OUTBOUND_EMAIL_PROVIDER=sendgrid`

Setup:

1. Configure Inbound Parse to forward to `/webhooks/email?provider=sendgrid`.
2. Store outbound API credentials in `SENDGRID_API_KEY`.
3. Configure `SENDGRID_FROM_EMAIL` to a verified sender.

## Security Notes

- Do not log access tokens, API keys, webhook signatures, or full customer message content.
- Use HTTPS for all provider webhook callbacks.
- Rotate provider secrets if webhook signature verification fails unexpectedly.
- Keep channel settings responses sanitized; return only connection status and non-secret metadata.

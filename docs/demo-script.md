# Final Demo Script

Use this as the presentation narrative for Smart Helpdesk AI. The demo is designed to work in local mock mode while showing the same product flow that production integrations will use.

## 1. Business Problem

Small online shops receive repetitive customer questions across website chat, Facebook, and email. Owners or agents often handle support manually while also managing sales, fulfillment, and operations.

Key pain points to explain:

- Customers expect fast answers about shipping, refunds, warranty, and product policies.
- Slow replies can lose sales.
- Complaints are easy to miss when staff are offline or busy.
- Hiring people to monitor every channel all day is expensive.

Smart Helpdesk AI solves this by answering common questions automatically and escalating risky conversations to a human agent.

## 2. Admin Uploads Knowledge Base

Open Web Admin as `super_admin`.

Demo action:

1. Go to Knowledge Base.
2. Upload `docs/demo-data/sample-support-policy.txt`.
3. Show the processing state and ready/chunk count result.

What to say:

- The AI does not invent store policies from general knowledge.
- Uploaded business documents are extracted, chunked, embedded, and stored in ChromaDB.
- Super Admin controls the Knowledge Base; agents cannot upload or modify it.

## 3. Customer Asks FAQ

Open `/widget-demo`.

Demo message:

```text
How long does standard shipping take?
```

What to show:

- The floating chat widget opens on a storefront-like page.
- The customer message is sent through the web-message boundary.
- The widget shows a typing/loading state while processing.

## 4. AI Answers Instantly

Expected result:

- AI classifies the message as a normal question.
- RAG retrieves matching Knowledge Base chunks.
- The bot replies with the shipping answer and keeps the conversation in the same thread.

What to say:

- The AI service has deterministic local fallback for demo reliability.
- With production LLM credentials, the same endpoint can generate answers using only retrieved context.
- If the AI cannot find enough context, it escalates instead of guessing.

## 5. Customer Complains

Send a second message in the widget:

```text
My delivery is late and I want a refund.
```

What to show:

- The conversation remains continuous.
- The message contains complaint-like terms that trigger the classifier.

## 6. AI Escalates

Expected result:

- Intent is classified as `complaint`.
- The system creates or updates an urgent ticket.
- The bot sends a handoff-style response instead of pretending to solve the complaint.

What to say:

- Complaints and low-confidence answers are routed to staff.
- Spam is ignored after classification.
- This protects customer trust and prevents serious messages from being buried.

## 7. Agent Receives Ticket/Notification

Open Web Admin as `agent`, or show the mobile app if available.

What to show:

- Agent navigation only includes the support areas they can access.
- Inbox lists assigned/open tickets.
- The urgent complaint appears with source, status, intent, customer, preview, and timestamp.
- Online staff can receive persisted notifications and FCM through the production abstraction.

What to say:

- Super Admin sees all tickets.
- Agents see tickets assigned to them and open tickets.
- Disabled users are rejected by backend auth/RBAC.

## 8. Agent Replies And Resolves

Open the ticket detail/conversation panel.

Demo action:

1. Click assign to me if needed.
2. Send a human reply.
3. Resolve the ticket.

Example reply:

```text
Thanks for letting us know. I will check your delivery status and help with the refund request.
```

What to show:

- The human message is saved as `sender_type = human`.
- The response is routed to the original ticket source boundary: web, Facebook, or email.
- Resolve moves the ticket to the final state while preserving the message history.

## 9. Dashboard Updates

Return to Dashboard as `super_admin`.

What to show:

- Open ticket count.
- Total messages today.
- AI handling rate.
- Average response time.
- 7-day message trend.
- Top questions.

What to say:

- The dashboard gives the owner operational visibility.
- The main value is not only automation, but also knowing which conversations need human attention.

## Honest Demo Notes

- Local demo mode avoids real external credentials and uses mock auth/data where needed.
- Real Supabase, Facebook, Email, FCM, and LLM credentials are production setup tasks.
- The web widget demo can use stable mocked browser responses; API curl commands in `docs/local-demo.md` exercise the real local API and AI services.
- Screenshots should be generated from the running app immediately before final submission if needed.

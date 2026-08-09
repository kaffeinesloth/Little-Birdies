# Supabase

Supabase database, auth, realtime, and storage setup for Smart Helpdesk AI.

## Contents

- SQL migrations in `migrations/`.
- Row Level Security policies for staff access.
- Placeholder profile seed notes.
- Instructions for applying migrations locally and in the Supabase dashboard.

## Auth Model

Supabase Auth owns login identities in `auth.users`. The application profile table is `public.users`, where `users.id` references `auth.users(id)`.

Do not store passwords in migrations. Create staff login accounts through Supabase Auth, then create matching `public.users` profile rows with the Auth user IDs.

## Apply Migrations

Using the Supabase CLI from the repository root:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

For local development:

```bash
supabase start
supabase db reset
```

If you are using the Supabase dashboard instead of the CLI, open SQL Editor and run the migration files from `infra/supabase/migrations` in filename order.

## Seed Data

The initial schema migration includes a commented placeholder profile seed. To use it:

1. Create users through Supabase Auth.
2. Copy their real `auth.users.id` UUIDs.
3. Replace the placeholder UUIDs in the commented seed block.
4. Run only the profile inserts.

Never add real passwords, API keys, or production credentials to SQL migrations.

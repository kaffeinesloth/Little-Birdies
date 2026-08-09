# Migrations

Supabase SQL migrations for Smart Helpdesk AI.

## Files

- `202608080001_initial_schema.sql`: enums, core tables, indexes, update triggers, RLS policies, and commented placeholder profile seeds.

## Apply Order

Run migrations in filename order.

Using Supabase CLI from the repository root:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

For local Supabase:

```bash
supabase start
supabase db reset
```

If using the dashboard SQL Editor, paste and run each migration file in order.

## Supabase Auth Requirement

`auth.users` is managed by Supabase Auth. The `public.users` table is only an application profile table and references `auth.users(id)`.

Do not store passwords in migrations. Create auth users through Supabase Auth, then insert matching profile rows into `public.users`.

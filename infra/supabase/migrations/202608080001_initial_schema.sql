-- Smart Helpdesk AI initial Supabase schema.
-- Supabase Auth owns authentication records in auth.users.
-- public.users stores application profile and RBAC data only.

create extension if not exists "pgcrypto";

create type public.user_role as enum ('super_admin', 'agent');
create type public.user_status as enum ('online', 'offline', 'disabled');
create type public.channel_type as enum ('web', 'facebook', 'email');
create type public.ticket_status as enum ('open', 'in_progress', 'pending', 'resolved');
create type public.intent_type as enum ('question', 'complaint', 'spam');
create type public.sender_type as enum ('customer', 'bot', 'human');
create type public.document_file_type as enum ('pdf', 'docx', 'txt');
create type public.embedding_status as enum ('processing', 'ready', 'error');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  role public.user_role not null default 'agent',
  status public.user_status not null default 'offline',
  avatar_url text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  customer_id text not null,
  customer_name text,
  source public.channel_type not null,
  status public.ticket_status not null default 'open',
  intent public.intent_type not null default 'question',
  summary text,
  assigned_to uuid references public.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tickets_resolved_at_check check (
    (status = 'resolved' and resolved_at is not null)
    or (status <> 'resolved')
  )
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  sender_type public.sender_type not null,
  sender_id text not null,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  file_url text not null,
  file_type public.document_file_type not null,
  embedding_status public.embedding_status not null default 'processing',
  chunk_count integer not null default 0 check (chunk_count >= 0),
  uploaded_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.channels (
  id uuid primary key default gen_random_uuid(),
  type public.channel_type not null unique,
  config jsonb not null default '{}'::jsonb,
  is_active boolean not null default false,
  connected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  recipient_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

create trigger tickets_set_updated_at
before update on public.tickets
for each row execute function public.set_updated_at();

create trigger messages_set_updated_at
before update on public.messages
for each row execute function public.set_updated_at();

create trigger documents_set_updated_at
before update on public.documents
for each row execute function public.set_updated_at();

create trigger channels_set_updated_at
before update on public.channels
for each row execute function public.set_updated_at();

create trigger notifications_set_updated_at
before update on public.notifications
for each row execute function public.set_updated_at();

create index tickets_status_idx on public.tickets(status);
create index tickets_source_idx on public.tickets(source);
create index tickets_assigned_to_idx on public.tickets(assigned_to);
create index tickets_created_at_idx on public.tickets(created_at desc);
create index tickets_customer_source_open_idx
  on public.tickets(customer_id, source)
  where status in ('open', 'pending', 'in_progress');

create index messages_ticket_id_idx on public.messages(ticket_id);
create index messages_created_at_idx on public.messages(created_at desc);
create index messages_ticket_created_at_idx on public.messages(ticket_id, created_at);

create index notifications_recipient_id_idx on public.notifications(recipient_id);
create index notifications_is_read_idx on public.notifications(is_read);
create index notifications_recipient_is_read_idx on public.notifications(recipient_id, is_read);

create index documents_embedding_status_idx on public.documents(embedding_status);

alter table public.users enable row level security;
alter table public.tickets enable row level security;
alter table public.messages enable row level security;
alter table public.documents enable row level security;
alter table public.channels enable row level security;
alter table public.notifications enable row level security;

create or replace function public.current_user_role()
returns public.user_role
language sql
security definer
set search_path = public
stable
as $$
  select role from public.users where id = auth.uid()
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.current_user_role() = 'super_admin', false)
$$;

create policy "users can read own profile"
on public.users for select
using (id = auth.uid() or public.is_super_admin());

create policy "super admins can manage user profiles"
on public.users for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy "super admins can access all tickets"
on public.tickets for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy "agents can read assigned or open tickets"
on public.tickets for select
using (
  public.current_user_role() = 'agent'
  and (assigned_to = auth.uid() or status = 'open')
);

create policy "agents can update assigned or open tickets"
on public.tickets for update
using (
  public.current_user_role() = 'agent'
  and (assigned_to = auth.uid() or status = 'open')
)
with check (
  public.current_user_role() = 'agent'
  and (assigned_to = auth.uid() or assigned_to is null)
);

create policy "staff can read messages for visible tickets"
on public.messages for select
using (
  exists (
    select 1
    from public.tickets
    where tickets.id = messages.ticket_id
      and (
        public.is_super_admin()
        or (
          public.current_user_role() = 'agent'
          and (tickets.assigned_to = auth.uid() or tickets.status = 'open')
        )
      )
  )
);

create policy "staff can insert messages for visible tickets"
on public.messages for insert
with check (
  exists (
    select 1
    from public.tickets
    where tickets.id = messages.ticket_id
      and (
        public.is_super_admin()
        or (
          public.current_user_role() = 'agent'
          and (tickets.assigned_to = auth.uid() or tickets.status = 'open')
        )
      )
  )
);

create policy "super admins can manage documents"
on public.documents for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy "super admins can manage channels"
on public.channels for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy "users can read own notifications"
on public.notifications for select
using (recipient_id = auth.uid() or public.is_super_admin());

create policy "users can update own notifications"
on public.notifications for update
using (recipient_id = auth.uid() or public.is_super_admin())
with check (recipient_id = auth.uid() or public.is_super_admin());

create policy "super admins can insert notifications"
on public.notifications for insert
with check (public.is_super_admin());

-- Optional placeholder profile seed.
-- Before enabling this block, create matching users through Supabase Auth and replace
-- the UUID values below with the real auth.users.id values. Do not store passwords here.
/*
insert into public.users (id, email, full_name, role, status)
values
  ('00000000-0000-0000-0000-000000000001', 'super-admin@example.com', 'Super Admin', 'super_admin', 'offline'),
  ('00000000-0000-0000-0000-000000000002', 'agent@example.com', 'Support Agent', 'agent', 'offline');
*/

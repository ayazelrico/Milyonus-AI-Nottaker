-- Remote migration version: 20261003135317
create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;

create table public.profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    display_name text check (display_name is null or char_length(display_name) between 1 and 120),
    locale text not null default 'en' check (locale in ('en', 'tr')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.workspaces (
    id uuid primary key default gen_random_uuid(),
    name text not null check (char_length(name) between 1 and 120),
    created_by uuid not null references auth.users (id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.workspace_members (
    workspace_id uuid not null references public.workspaces (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    role text not null check (role in ('owner', 'member')),
    created_at timestamptz not null default now(),
    primary key (workspace_id, user_id)
);

create table public.meetings (
    id uuid primary key default gen_random_uuid(),
    workspace_id uuid not null references public.workspaces (id) on delete cascade,
    created_by uuid not null references auth.users (id) on delete restrict,
    title text not null check (char_length(title) between 1 and 240),
    status text not null default 'scheduled'
        check (status in ('scheduled', 'recording', 'paused', 'processing', 'completed', 'failed', 'cancelled')),
    language_code text not null default 'en' check (language_code in ('en', 'tr', 'auto')),
    consent_confirmed_at timestamptz,
    started_at timestamptz,
    ended_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint meetings_time_order check (ended_at is null or started_at is not null and ended_at >= started_at),
    constraint meetings_id_workspace_unique unique (id, workspace_id)
);

create table public.transcript_segments (
    id uuid primary key default gen_random_uuid(),
    meeting_id uuid not null,
    workspace_id uuid not null,
    created_by uuid not null references auth.users (id) on delete restrict,
    external_id text not null check (char_length(external_id) between 1 and 240),
    channel text not null check (channel in ('microphone', 'system')),
    start_ms bigint not null check (start_ms >= 0),
    end_ms bigint not null,
    content text not null,
    is_final boolean not null default false,
    revision integer not null default 0 check (revision >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint transcript_segment_time_order check (end_ms >= start_ms),
    constraint transcript_segment_meeting_workspace_fk
        foreign key (meeting_id, workspace_id)
        references public.meetings (id, workspace_id)
        on delete cascade,
    constraint transcript_segment_provider_identity
        unique (meeting_id, channel, external_id)
);

create index workspaces_created_by_idx on public.workspaces (created_by);
create index workspace_members_user_id_idx on public.workspace_members (user_id, workspace_id);
create index meetings_workspace_created_at_idx on public.meetings (workspace_id, created_at desc);
create index meetings_created_by_idx on public.meetings (created_by);
create index transcript_segments_meeting_timeline_idx
    on public.transcript_segments (meeting_id, start_ms, channel);
create index transcript_segments_workspace_idx on public.transcript_segments (workspace_id);
create index transcript_segments_created_by_idx on public.transcript_segments (created_by);

create function private.is_workspace_member(target_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select (select auth.uid()) is not null
        and exists (
            select 1
            from public.workspace_members as member
            where member.workspace_id = target_workspace_id
              and member.user_id = (select auth.uid())
        );
$$;

create function private.is_workspace_owner(target_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select (select auth.uid()) is not null
        and exists (
            select 1
            from public.workspace_members as member
            where member.workspace_id = target_workspace_id
              and member.user_id = (select auth.uid())
              and member.role = 'owner'
        );
$$;

create function private.add_workspace_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.workspace_members (workspace_id, user_id, role)
    values (new.id, new.created_by, 'owner');
    return new;
end;
$$;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = 'pg_catalog'
as $$
begin
    new.updated_at = statement_timestamp();
    return new;
end;
$$;

revoke all on function private.is_workspace_member(uuid) from public;
revoke all on function private.is_workspace_owner(uuid) from public;
revoke all on function private.add_workspace_owner() from public;
revoke all on function private.set_updated_at() from public;

grant execute on function private.is_workspace_member(uuid) to authenticated, service_role;
grant execute on function private.is_workspace_owner(uuid) to authenticated, service_role;
grant execute on function private.add_workspace_owner() to authenticated, service_role;
grant execute on function private.set_updated_at() to authenticated, service_role;

create trigger workspaces_add_owner
after insert on public.workspaces
for each row execute function private.add_workspace_owner();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger workspaces_set_updated_at
before update on public.workspaces
for each row execute function private.set_updated_at();

create trigger meetings_set_updated_at
before update on public.meetings
for each row execute function private.set_updated_at();

create trigger transcript_segments_set_updated_at
before update on public.transcript_segments
for each row execute function private.set_updated_at();

alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.meetings enable row level security;
alter table public.transcript_segments enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.workspaces from anon, authenticated;
revoke all on table public.workspace_members from anon, authenticated;
revoke all on table public.meetings from anon, authenticated;
revoke all on table public.transcript_segments from anon, authenticated;

grant select, insert on table public.profiles to authenticated;
grant update (display_name, locale) on table public.profiles to authenticated;
grant select, insert, delete on table public.workspaces to authenticated;
grant update (name) on table public.workspaces to authenticated;
grant select on table public.workspace_members to authenticated;
grant select, insert, delete on table public.meetings to authenticated;
grant update (title, status, language_code, consent_confirmed_at, started_at, ended_at)
    on table public.meetings to authenticated;
grant select, insert, delete on table public.transcript_segments to authenticated;
grant update (start_ms, end_ms, content, is_final, revision)
    on table public.transcript_segments to authenticated;

grant all on table public.profiles to service_role;
grant all on table public.workspaces to service_role;
grant all on table public.workspace_members to service_role;
grant all on table public.meetings to service_role;
grant all on table public.transcript_segments to service_role;

create policy profiles_select_self
on public.profiles
for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy profiles_insert_self
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy profiles_update_self
on public.profiles
for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy workspaces_select_member
on public.workspaces
for select
to authenticated
using ((select private.is_workspace_member(id)));

create policy workspaces_insert_creator
on public.workspaces
for insert
to authenticated
with check ((select auth.uid()) is not null and created_by = (select auth.uid()));

create policy workspaces_update_owner
on public.workspaces
for update
to authenticated
using ((select private.is_workspace_owner(id)))
with check ((select private.is_workspace_owner(id)));

create policy workspaces_delete_owner
on public.workspaces
for delete
to authenticated
using ((select private.is_workspace_owner(id)));

create policy workspace_members_select_member
on public.workspace_members
for select
to authenticated
using ((select private.is_workspace_member(workspace_id)));

create policy meetings_select_member
on public.meetings
for select
to authenticated
using ((select private.is_workspace_member(workspace_id)));

create policy meetings_insert_member
on public.meetings
for insert
to authenticated
with check (
    (select auth.uid()) is not null
    and created_by = (select auth.uid())
    and (select private.is_workspace_member(workspace_id))
);

create policy meetings_update_member
on public.meetings
for update
to authenticated
using ((select private.is_workspace_member(workspace_id)))
with check ((select private.is_workspace_member(workspace_id)));

create policy meetings_delete_creator_or_owner
on public.meetings
for delete
to authenticated
using (
    created_by = (select auth.uid())
    or (select private.is_workspace_owner(workspace_id))
);

create policy transcript_segments_select_member
on public.transcript_segments
for select
to authenticated
using ((select private.is_workspace_member(workspace_id)));

create policy transcript_segments_insert_member
on public.transcript_segments
for insert
to authenticated
with check (
    (select auth.uid()) is not null
    and created_by = (select auth.uid())
    and (select private.is_workspace_member(workspace_id))
);

create policy transcript_segments_update_creator
on public.transcript_segments
for update
to authenticated
using (created_by = (select auth.uid()))
with check (
    created_by = (select auth.uid())
    and (select private.is_workspace_member(workspace_id))
);

create policy transcript_segments_delete_creator_or_owner
on public.transcript_segments
for delete
to authenticated
using (
    created_by = (select auth.uid())
    or (select private.is_workspace_owner(workspace_id))
);

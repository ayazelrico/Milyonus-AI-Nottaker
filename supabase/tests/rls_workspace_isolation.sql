begin;

insert into auth.users (id, aud, role, email)
values
    ('10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'user-a@example.invalid'),
    ('20000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'user-b@example.invalid');

insert into public.profiles (user_id, display_name)
values
    ('10000000-0000-0000-0000-000000000001', 'Synthetic User A'),
    ('20000000-0000-0000-0000-000000000002', 'Synthetic User B');

insert into public.workspaces (id, name, created_by)
values
    ('a0000000-0000-0000-0000-000000000001', 'Synthetic Workspace A', '10000000-0000-0000-0000-000000000001'),
    ('b0000000-0000-0000-0000-000000000002', 'Synthetic Workspace B', '20000000-0000-0000-0000-000000000002');

insert into public.meetings (id, workspace_id, created_by, title)
values
    (
        'a1000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        'Synthetic Meeting A'
    ),
    (
        'b1000000-0000-0000-0000-000000000002',
        'b0000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000002',
        'Synthetic Meeting B'
    );

insert into public.transcript_segments (
    id,
    meeting_id,
    workspace_id,
    created_by,
    external_id,
    channel,
    start_ms,
    end_ms,
    content,
    is_final
)
values
    (
        'a2000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        'segment-a',
        'microphone',
        0,
        1000,
        'Synthetic transcript A',
        true
    ),
    (
        'b2000000-0000-0000-0000-000000000002',
        'b1000000-0000-0000-0000-000000000002',
        'b0000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000002',
        'segment-b',
        'system',
        0,
        1000,
        'Synthetic transcript B',
        true
    );

do $test$
begin
    if has_table_privilege('anon', 'public.profiles', 'select')
        or has_table_privilege('anon', 'public.workspaces', 'select')
        or has_table_privilege('anon', 'public.workspace_members', 'select')
        or has_table_privilege('anon', 'public.meetings', 'select')
        or has_table_privilege('anon', 'public.transcript_segments', 'select') then
        raise exception 'Grant failure: anon must not have select access to application tables';
    end if;

    if has_function_privilege(
        'anon',
        'public.upsert_transcript_segments(uuid, uuid, jsonb)',
        'execute'
    ) then
        raise exception 'Grant failure: anon must not execute transcript batch writes';
    end if;
end;
$test$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $test$
begin
    if (select count(*) from public.profiles) <> 1 then
        raise exception 'RLS failure: user A must see only their own profile';
    end if;

    if (select count(*) from public.workspaces) <> 1 then
        raise exception 'RLS failure: user A must see only workspace A';
    end if;

    if (select count(*) from public.workspace_members) <> 1 then
        raise exception 'RLS failure: user A must see only workspace A membership';
    end if;

    if (select count(*) from public.meetings) <> 1 then
        raise exception 'RLS failure: user A must see only meeting A';
    end if;

    if (select count(*) from public.transcript_segments) <> 1 then
        raise exception 'RLS failure: user A must see only transcript A';
    end if;

    if public.upsert_transcript_segments(
        'a0000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001',
        '[{"id":"a3000000-0000-0000-0000-000000000001","channel":"microphone","content":"Synthetic RPC transcript A","start_ms":1000,"end_ms":2000,"is_final":false,"revision":1}]'::jsonb
    ) <> 1 then
        raise exception 'RPC failure: valid transcript batch was not accepted';
    end if;

    if (
        select count(*)
        from public.transcript_segments
        where id = 'a3000000-0000-0000-0000-000000000001'
            and content = 'Synthetic RPC transcript A'
            and revision = 1
    ) <> 1 then
        raise exception 'RPC failure: accepted segment was not persisted';
    end if;

    begin
        insert into public.meetings (workspace_id, created_by, title)
        values (
            'b0000000-0000-0000-0000-000000000002',
            '10000000-0000-0000-0000-000000000001',
            'Cross-workspace write must fail'
        );
        raise exception 'RLS failure: user A wrote meeting data into workspace B';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.transcript_segments
        set content = 'Cross-workspace update must fail'
        where id = 'b2000000-0000-0000-0000-000000000002';

        if found then
            raise exception 'RLS failure: user A updated transcript B';
        end if;
    end;

    begin
        perform public.upsert_transcript_segments(
            'b0000000-0000-0000-0000-000000000002',
            'b1000000-0000-0000-0000-000000000002',
            '[{"id":"a3000000-0000-0000-0000-000000000002","channel":"system","content":"Cross-workspace RPC must fail","start_ms":0,"end_ms":1,"is_final":true,"revision":1}]'::jsonb
        );
        raise exception 'RLS failure: user A wrote an RPC segment into workspace B';
    exception
        when insufficient_privilege then null;
    end;
end;
$test$;

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);

do $test$
begin
    if (select count(*) from public.profiles) <> 1 then
        raise exception 'RLS failure: user B must see only their own profile';
    end if;

    if (select count(*) from public.workspaces) <> 1 then
        raise exception 'RLS failure: user B must see only workspace B';
    end if;

    if (select count(*) from public.meetings) <> 1 then
        raise exception 'RLS failure: user B must see only meeting B';
    end if;

    if (select count(*) from public.transcript_segments) <> 1 then
        raise exception 'RLS failure: user B must see only transcript B';
    end if;
end;
$test$;

reset role;
rollback;

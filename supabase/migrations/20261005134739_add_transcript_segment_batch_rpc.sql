create function public.upsert_transcript_segments(
    p_workspace_id uuid,
    p_meeting_id uuid,
    p_segments jsonb
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
    accepted_count integer;
begin
    if (select auth.uid()) is null then
        raise exception using errcode = '42501', message = 'authentication required';
    end if;

    if p_workspace_id is null
        or p_meeting_id is null
        or p_segments is null
        or jsonb_typeof(p_segments) <> 'array'
        or jsonb_array_length(p_segments) not between 1 and 100
    then
        raise exception using errcode = '22023', message = 'invalid segment batch';
    end if;

    if exists (
        select 1
        from jsonb_to_recordset(p_segments) as segment(
            id uuid,
            channel text,
            content text,
            start_ms bigint,
            end_ms bigint,
            is_final boolean,
            revision integer
        )
        where segment.id is null
            or segment.channel is null
            or segment.channel not in ('microphone', 'system')
            or segment.content is null
            or char_length(segment.content) not between 1 and 10000
            or segment.start_ms is null
            or segment.start_ms < 0
            or segment.end_ms is null
            or segment.end_ms < segment.start_ms
            or segment.is_final is null
            or segment.revision is null
            or segment.revision < 1
    ) then
        raise exception using errcode = '22023', message = 'invalid transcript segment';
    end if;

    if (
        select count(*) <> count(distinct segment.id)
        from jsonb_to_recordset(p_segments) as segment(id uuid)
    ) then
        raise exception using errcode = '22023', message = 'duplicate transcript segment';
    end if;

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
        is_final,
        revision
    )
    select
        segment.id,
        p_meeting_id,
        p_workspace_id,
        (select auth.uid()),
        segment.id::text,
        segment.channel,
        segment.start_ms,
        segment.end_ms,
        segment.content,
        segment.is_final,
        segment.revision
    from jsonb_to_recordset(p_segments) as segment(
        id uuid,
        channel text,
        content text,
        start_ms bigint,
        end_ms bigint,
        is_final boolean,
        revision integer
    )
    on conflict on constraint transcript_segment_provider_identity
    do update set
        start_ms = excluded.start_ms,
        end_ms = excluded.end_ms,
        content = excluded.content,
        is_final = excluded.is_final,
        revision = excluded.revision
    where excluded.revision > public.transcript_segments.revision
        and public.transcript_segments.created_by = (select auth.uid())
        and (not public.transcript_segments.is_final or excluded.is_final);

    accepted_count := jsonb_array_length(p_segments);
    return accepted_count;
end;
$$;

revoke all on function public.upsert_transcript_segments(uuid, uuid, jsonb) from public, anon;
grant execute on function public.upsert_transcript_segments(uuid, uuid, jsonb)
    to authenticated, service_role;

comment on function public.upsert_transcript_segments(uuid, uuid, jsonb) is
    'Idempotently persists authenticated transcript segment revisions under existing RLS policies.';

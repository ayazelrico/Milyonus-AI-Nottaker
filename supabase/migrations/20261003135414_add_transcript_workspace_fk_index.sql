-- Remote migration version: 20261003135414
create index transcript_segments_meeting_workspace_idx
    on public.transcript_segments (meeting_id, workspace_id);

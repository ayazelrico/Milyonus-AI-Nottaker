import { describe, expect, it, vi } from 'vitest';
import { createSupabaseSegmentWriter } from '../src/transcript/supabase-segment-writer.js';

const identity = { id: '44757ce8-0661-49d0-aaf7-4567e0808c0a' };
const batch = {
  workspaceId: '5b375821-c493-45bc-82f8-608e35ca3e24',
  meetingId: '07602822-09c1-4bed-b476-993b21671f94',
  segments: [
    {
      id: '4587cc56-a7f8-413e-9074-a6189d312021',
      channel: 'microphone' as const,
      text: 'private transcript fixture',
      startMilliseconds: 10,
      endMilliseconds: 20,
      isFinal: true,
      revision: 2,
    },
  ],
};

describe('Supabase transcript segment writer', () => {
  it('forwards the user JWT to an RLS-protected RPC and maps the payload', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response('1', { status: 200 }));
    const writer = createSupabaseSegmentWriter(
      {
        url: 'https://project.supabase.co',
        publishableKey: 'publishable-key-fixture-value',
      },
      fetcher,
    );

    await expect(writer(identity, 'header.payload.signature', batch)).resolves.toBe(1);
    expect(fetcher).toHaveBeenCalledOnce();
    const [url, options] = fetcher.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://project.supabase.co/rest/v1/rpc/upsert_transcript_segments');
    expect(options.headers).toMatchObject({
      apikey: 'publishable-key-fixture-value',
      authorization: 'Bearer header.payload.signature',
    });
    if (typeof options.body !== 'string') throw new Error('Expected a serialized request body');
    expect(JSON.parse(options.body)).toEqual({
      p_workspace_id: batch.workspaceId,
      p_meeting_id: batch.meetingId,
      p_segments: [
        {
          id: batch.segments[0]?.id,
          channel: 'microphone',
          content: 'private transcript fixture',
          start_ms: 10,
          end_ms: 20,
          is_final: true,
          revision: 2,
        },
      ],
    });
  });

  it('rejects provider failures without exposing response content', async () => {
    const writer = createSupabaseSegmentWriter(
      {
        url: 'https://project.supabase.co',
        publishableKey: 'publishable-key-fixture-value',
      },
      () => Promise.resolve(new Response('private-provider-fixture', { status: 403 })),
    );
    await expect(writer(identity, 'header.payload.signature', batch)).rejects.not.toThrow(
      /private-provider-fixture|header\.payload\.signature/,
    );
  });
});

import type { Identity } from '../auth/verify-token.js';
import type { SupabaseDataConfig } from '../config/env.js';

export interface TranscriptSegmentInput {
  readonly id: string;
  readonly channel: 'microphone' | 'system';
  readonly text: string;
  readonly startMilliseconds: number;
  readonly endMilliseconds: number;
  readonly isFinal: boolean;
  readonly revision: number;
}

export interface TranscriptBatchInput {
  readonly workspaceId: string;
  readonly meetingId: string;
  readonly segments: readonly TranscriptSegmentInput[];
}

export type TranscriptSegmentWriter = (
  identity: Identity,
  accessToken: string,
  batch: TranscriptBatchInput,
) => Promise<number>;

export function createSupabaseSegmentWriter(
  config: SupabaseDataConfig,
  fetcher: typeof fetch = fetch,
): TranscriptSegmentWriter {
  const endpoint = `${config.url}/rest/v1/rpc/upsert_transcript_segments`;
  return async (identity, accessToken, batch) => {
    const response = await fetcher(endpoint, {
      method: 'POST',
      headers: {
        apikey: config.publishableKey,
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify({
        p_workspace_id: batch.workspaceId,
        p_meeting_id: batch.meetingId,
        p_segments: batch.segments.map((segment) => ({
          id: segment.id,
          channel: segment.channel,
          content: segment.text,
          start_ms: segment.startMilliseconds,
          end_ms: segment.endMilliseconds,
          is_final: segment.isFinal,
          revision: segment.revision,
        })),
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) throw new Error('Transcript persistence failed');
    const payload: unknown = await response.json();
    if (
      !Number.isSafeInteger(payload) ||
      (payload as number) < 0 ||
      (payload as number) > batch.segments.length
    ) {
      throw new Error('Invalid transcript persistence response');
    }
    void identity;
    return payload as number;
  };
}

import { afterEach, describe, expect, it, vi } from 'vitest';
import { writeOperationalEvent } from '../src/observability.js';

afterEach(() => vi.restoreAllMocks());

describe('operational events', () => {
  it('projects allowed fields even if the runtime object contains sensitive extras', () => {
    const write = vi.spyOn(process.stdout, 'write').mockReturnValue(true);
    const event = {
      event: 'request_failed' as const,
      requestId: '44757ce8-0661-49d0-aaf7-4567e0808c0a',
      statusCode: 500,
      transcript: 'private-transcript-fixture',
      error: new Error('private-provider-fixture'),
      authorization: 'private-token-fixture',
    };
    writeOperationalEvent(event);
    expect(write).toHaveBeenCalledWith(
      JSON.stringify({
        event: 'request_failed',
        requestId: event.requestId,
        statusCode: 500,
      }) + '\n',
    );
  });
});

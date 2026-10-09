import { GenerationError } from './contracts.js';

interface ServerEvent {
  readonly event: string;
  readonly data: string;
}

/** Bounded UTF-8 SSE framing. No raw stream content escapes through errors. */
export async function* serverEvents(
  body: ReadableStream<Uint8Array>,
  signal: AbortSignal,
): AsyncGenerator<ServerEvent> {
  const reader = body.getReader();
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let pending = '';
  let event = '';
  let data: string[] = [];
  let eventSize = 0;
  let totalBytes = 0;
  const cancel = () => {
    void reader.cancel().catch(() => undefined);
  };
  signal.addEventListener('abort', cancel, { once: true });
  try {
    while (true) {
      signal.throwIfAborted();
      const next = await reader.read();
      signal.throwIfAborted();
      if (next.done) break;
      totalBytes += next.value.byteLength;
      if (totalBytes > 262_144) throw new GenerationError('invalid_response');
      pending += decoder.decode(next.value, { stream: true });
      let match: RegExpExecArray | null;
      while ((match = /\r\n|\r(?!$)|\n/.exec(pending)) !== null) {
        const line = pending.slice(0, match.index);
        pending = pending.slice(match.index + match[0].length);
        eventSize += line.length;
        if (eventSize > 65_536) throw new GenerationError('invalid_response');
        if (line === '') {
          if (data.length > 0) yield { event: event || 'message', data: data.join('\n') };
          event = '';
          data = [];
          eventSize = 0;
        } else if (!line.startsWith(':')) {
          const colon = line.indexOf(':');
          const field = colon === -1 ? line : line.slice(0, colon);
          const raw = colon === -1 ? '' : line.slice(colon + 1);
          const value = raw.startsWith(' ') ? raw.slice(1) : raw;
          if (field === 'event') event = value;
          if (field === 'data') data.push(value);
        }
      }
      if (pending.length + eventSize > 65_536) throw new GenerationError('invalid_response');
    }
    pending += decoder.decode();
    // A terminal CR is a line ending, but an undispatched event is still incomplete.
    if (pending === '\r' && data.length > 0) {
      yield { event: event || 'message', data: data.join('\n') };
    } else if (pending !== '' || data.length > 0) {
      throw new GenerationError('invalid_response');
    }
  } finally {
    signal.removeEventListener('abort', cancel);
    await reader.cancel().catch(() => undefined);
    reader.releaseLock();
  }
}

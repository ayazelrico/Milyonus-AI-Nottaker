export type OperationalEvent =
  | { readonly event: 'server_started'; readonly port: number }
  | { readonly event: 'startup_failed' | 'shutdown_failed' }
  | {
      readonly event: 'request_failed';
      readonly requestId: string;
      readonly statusCode: number;
    }
  | {
      readonly event: 'llm_completed';
      readonly requestId: string;
      readonly durationMilliseconds: number;
      readonly attempts: number;
      readonly inputTokens: number;
      readonly outputTokens: number;
      readonly cacheReadTokens: number;
      readonly cacheCreationTokens: number;
    };

export type EventSink = (event: OperationalEvent) => void;

/** No arbitrary fields or Error objects are accepted by the operational log interface. */
export const writeOperationalEvent: EventSink = (event) => {
  let metadata: OperationalEvent;
  switch (event.event) {
    case 'server_started':
      metadata = { event: event.event, port: event.port };
      break;
    case 'request_failed':
      metadata = {
        event: event.event,
        requestId: event.requestId,
        statusCode: event.statusCode,
      };
      break;
    case 'llm_completed':
      metadata = {
        event: event.event,
        requestId: event.requestId,
        durationMilliseconds: event.durationMilliseconds,
        attempts: event.attempts,
        inputTokens: event.inputTokens,
        outputTokens: event.outputTokens,
        cacheReadTokens: event.cacheReadTokens,
        cacheCreationTokens: event.cacheCreationTokens,
      };
      break;
    case 'startup_failed':
    case 'shutdown_failed':
      metadata = { event: event.event };
      break;
  }
  process.stdout.write(`${JSON.stringify(metadata)}\n`);
};

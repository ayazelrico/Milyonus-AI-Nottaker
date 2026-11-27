export type OperationalEvent =
  | { readonly event: 'server_started'; readonly port: number }
  | { readonly event: 'startup_failed' | 'shutdown_failed' }
  | {
      readonly event: 'insight_generated';
      readonly requestId: string;
      readonly model: string;
      readonly inputTokens: number;
      readonly outputTokens: number;
    }
  | {
      readonly event: 'request_failed';
      readonly requestId: string;
      readonly statusCode: number;
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
    case 'insight_generated':
      metadata = {
        event: event.event,
        requestId: event.requestId,
        model: event.model,
        inputTokens: event.inputTokens,
        outputTokens: event.outputTokens,
      };
      break;
    case 'startup_failed':
    case 'shutdown_failed':
      metadata = { event: event.event };
      break;
  }
  process.stdout.write(`${JSON.stringify(metadata)}\n`);
};

import { setTimeout as delay } from 'node:timers/promises';
import type { InsightConfig } from '../config/env.js';
import { generationOptions, models } from '../config/models.js';
import { GenerationError } from './contracts.js';
import type {
  GenerationEvent,
  GenerationInput,
  LanguageGenerator,
  TokenUsage,
} from './contracts.js';
import { serverEvents } from './sse.js';

const messagesUrl = 'https://api.anthropic.com/v1/messages';
const emptyUsage: TokenUsage = {
  inputTokens: 0,
  outputTokens: 0,
  cacheReadTokens: 0,
  cacheCreationTokens: 0,
};

function object(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new GenerationError('invalid_response');
  }
  return value as Record<string, unknown>;
}

function count(value: unknown, optional = false): number {
  if (value === undefined && optional) return 0;
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
    throw new GenerationError('invalid_response');
  }
  return value;
}

async function* attempt(
  config: InsightConfig,
  input: GenerationInput,
  model: keyof typeof generationOptions,
  signal: AbortSignal,
  request: typeof fetch,
  onUsage: (usage: TokenUsage) => void,
): AsyncGenerator<GenerationEvent> {
  let response: Response;
  try {
    response = await request(messagesUrl, {
      method: 'POST',
      redirect: 'error',
      headers: {
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        accept: 'text/event-stream',
      },
      body: JSON.stringify({
        model,
        max_tokens: input.task === 'triggerClassification' ? 256 : 1024,
        stream: true,
        ...generationOptions[model],
        system: [{ type: 'text', text: input.systemPrompt, cache_control: { type: 'ephemeral' } }],
        messages: [{ role: 'user', content: input.input }],
      }),
      signal,
    });
  } catch {
    throw new GenerationError('unavailable', true);
  }
  if (!response.ok) {
    await response.body?.cancel().catch(() => undefined);
    throw new GenerationError(
      'unavailable',
      [429, 500, 502, 503, 504, 529].includes(response.status),
    );
  }
  if (
    response.body === null ||
    !response.headers.get('content-type')?.startsWith('text/event-stream')
  ) {
    await response.body?.cancel().catch(() => undefined);
    throw new GenerationError('invalid_response');
  }

  let started = false;
  let stopped = false;
  let blockOpen = false;
  let blockSeen = false;
  let outputCharacters = 0;
  let usage = { ...emptyUsage };
  for await (const event of serverEvents(response.body, signal)) {
    const known = [
      'error',
      'message_start',
      'content_block_start',
      'content_block_delta',
      'content_block_stop',
      'message_delta',
      'message_stop',
    ];
    if (!known.includes(event.event)) continue;
    let parsed: unknown;
    try {
      parsed = JSON.parse(event.data);
    } catch {
      throw new GenerationError('invalid_response');
    }
    const payload = object(parsed);
    if (payload.type !== event.event) throw new GenerationError('invalid_response');
    switch (event.event) {
      case 'error': {
        const error = object(payload.error);
        throw new GenerationError(
          'unavailable',
          ['overloaded_error', 'rate_limit_error', 'api_error'].includes(String(error.type)),
        );
      }
      case 'message_start': {
        if (started) throw new GenerationError('invalid_response');
        const message = object(payload.message);
        if (
          message.role !== 'assistant' ||
          message.type !== 'message' ||
          typeof message.model !== 'string' ||
          message.model.length > 128
        ) {
          throw new GenerationError('invalid_response');
        }
        const value = object(message.usage);
        usage = {
          inputTokens: count(value.input_tokens),
          outputTokens: count(value.output_tokens),
          cacheReadTokens: count(value.cache_read_input_tokens, true),
          cacheCreationTokens: count(value.cache_creation_input_tokens, true),
        };
        onUsage(usage);
        started = true;
        break;
      }
      case 'content_block_start': {
        if (!started || stopped || blockSeen || payload.index !== 0) {
          throw new GenerationError('invalid_response');
        }
        const block = object(payload.content_block);
        if (block.type !== 'text' || block.text !== '')
          throw new GenerationError('invalid_response');
        blockOpen = true;
        blockSeen = true;
        break;
      }
      case 'content_block_delta': {
        if (!blockOpen || stopped || payload.index !== 0)
          throw new GenerationError('invalid_response');
        const delta = object(payload.delta);
        if (delta.type !== 'text_delta' || typeof delta.text !== 'string') {
          throw new GenerationError('invalid_response');
        }
        outputCharacters += delta.text.length;
        if (outputCharacters > 16_384) throw new GenerationError('invalid_response');
        if (delta.text !== '') yield { type: 'text', text: delta.text };
        break;
      }
      case 'content_block_stop':
        if (!blockOpen || payload.index !== 0) throw new GenerationError('invalid_response');
        blockOpen = false;
        break;
      case 'message_delta': {
        if (!started || !blockSeen || blockOpen || stopped)
          throw new GenerationError('invalid_response');
        const stopReason = object(payload.delta).stop_reason;
        if (stopReason !== null && stopReason !== undefined && stopReason !== 'end_turn') {
          throw new GenerationError('invalid_response');
        }
        const outputTokens = count(object(payload.usage).output_tokens);
        if (outputTokens < usage.outputTokens) throw new GenerationError('invalid_response');
        usage.outputTokens = outputTokens;
        onUsage(usage);
        stopped = stopReason === 'end_turn';
        break;
      }
      case 'message_stop':
        if (!stopped || outputCharacters === 0) throw new GenerationError('invalid_response');
        yield { type: 'completed', model, attempts: 1, usage };
        return;
    }
  }
  throw new GenerationError('invalid_response');
}

/** At most two primary attempts and one live fallback, within one ten-second deadline. */
export function createAnthropicGenerator(
  config: InsightConfig,
  request: typeof fetch = fetch,
): LanguageGenerator {
  return async function* (input) {
    if (
      input.systemPrompt.length < 1 ||
      input.systemPrompt.length > 32_768 ||
      input.input.length < 1 ||
      input.input.length > 24_576
    ) {
      throw new GenerationError('invalid_response');
    }
    const lifetime = new AbortController();
    const deadline = AbortSignal.timeout(10_000);
    const signal = AbortSignal.any([input.signal, deadline, lifetime.signal]);
    const primary = models[input.task];
    const candidates =
      input.task === 'liveInsight'
        ? [primary, primary, models.liveInsightFallback]
        : [primary, primary];
    const total = { ...emptyUsage };
    let outputStarted = false;
    try {
      for (let index = 0; index < candidates.length; index += 1) {
        signal.throwIfAborted();
        const model = candidates[index];
        if (model === undefined) throw new GenerationError('unavailable');
        let usage = { ...emptyUsage };
        try {
          for await (const event of attempt(config, input, model, signal, request, (value) => {
            usage = { ...value };
          })) {
            signal.throwIfAborted();
            if (event.type === 'text') {
              outputStarted = true;
              yield event;
            } else {
              yield {
                ...event,
                attempts: index + 1,
                usage: {
                  inputTokens: total.inputTokens + usage.inputTokens,
                  outputTokens: total.outputTokens + usage.outputTokens,
                  cacheReadTokens: total.cacheReadTokens + usage.cacheReadTokens,
                  cacheCreationTokens: total.cacheCreationTokens + usage.cacheCreationTokens,
                },
              };
              return;
            }
          }
        } catch (error) {
          if (signal.aborted) throw error;
          if (
            outputStarted ||
            !(error instanceof GenerationError) ||
            !error.retryable ||
            index === candidates.length - 1
          ) {
            throw error;
          }
          await delay(200 * (index + 1), undefined, { signal });
        } finally {
          total.inputTokens += usage.inputTokens;
          total.outputTokens += usage.outputTokens;
          total.cacheReadTokens += usage.cacheReadTokens;
          total.cacheCreationTokens += usage.cacheCreationTokens;
        }
      }
    } catch (error) {
      if (input.signal.aborted) throw new GenerationError('cancelled');
      if (deadline.aborted) throw new GenerationError('timeout');
      if (error instanceof GenerationError) throw error;
      throw new GenerationError('unavailable');
    } finally {
      lifetime.abort();
    }
  };
}

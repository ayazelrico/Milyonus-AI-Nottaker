import type { AnthropicConfig } from '../config/env.js';
import { LlmError } from './types.js';
import type { LlmProvider, LlmRequest, LlmStreamEvent } from './types.js';

export interface AnthropicProviderOptions {
  readonly fetch?: typeof fetch;
  readonly timeoutMs?: number;
  readonly maxAttempts?: number;
  readonly baseDelayMs?: number;
  readonly sleep?: (milliseconds: number) => Promise<void>;
}

const endpoint = 'https://api.anthropic.com/v1/messages';
const apiVersion = '2023-06-01';

function isRetryableStatus(status: number): boolean {
  return status === 408 || status === 409 || status === 429 || status >= 500;
}

function parseSseData(block: string): unknown {
  const data = block
    .split('\n')
    .filter((line) => line.startsWith('data:'))
    .map((line) => line.slice(5).trimStart())
    .join('\n');
  if (data === '') return undefined;
  try {
    return JSON.parse(data) as unknown;
  } catch {
    return undefined;
  }
}

function toEvent(payload: unknown): LlmStreamEvent | undefined {
  if (typeof payload !== 'object' || payload === null) return undefined;
  const record = payload as Record<string, unknown>;
  if (record.type === 'content_block_delta') {
    const delta = record.delta as Record<string, unknown> | undefined;
    if (delta?.type === 'text_delta' && typeof delta.text === 'string') {
      return { type: 'delta', text: delta.text };
    }
  }
  if (record.type === 'message_delta') {
    const usage = record.usage as Record<string, unknown> | undefined;
    if (typeof usage?.output_tokens === 'number') {
      return { type: 'usage', usage: { inputTokens: 0, outputTokens: usage.output_tokens } };
    }
  }
  if (record.type === 'message_start') {
    const message = record.message as Record<string, unknown> | undefined;
    const usage = message?.usage as Record<string, unknown> | undefined;
    if (typeof usage?.input_tokens === 'number') {
      return { type: 'usage', usage: { inputTokens: usage.input_tokens, outputTokens: 0 } };
    }
  }
  return undefined;
}

/**
 * Streaming Anthropic Messages client. Retries happen only before the first byte of the response
 * body is consumed, so a caller never sees duplicated or partial output from a failed attempt.
 * Content, prompts and provider error bodies are never logged or surfaced.
 */
export function createAnthropicProvider(
  config: AnthropicConfig,
  options: AnthropicProviderOptions = {},
): LlmProvider {
  const fetchImpl = options.fetch ?? fetch;
  const timeoutMs = options.timeoutMs ?? 20_000;
  const maxAttempts = options.maxAttempts ?? 2;
  const baseDelayMs = options.baseDelayMs ?? 250;
  const sleep =
    options.sleep ??
    ((milliseconds: number) => new Promise<void>((done) => setTimeout(done, milliseconds)));

  async function open(request: LlmRequest): Promise<Response> {
    let lastError: LlmError = new LlmError('LLM_UNAVAILABLE', true);
    const callerAborted = (): boolean => request.signal?.aborted === true;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
      if (callerAborted()) throw new LlmError('LLM_UNAVAILABLE', false);
      const timeout = AbortSignal.timeout(timeoutMs);
      const signal =
        request.signal === undefined ? timeout : AbortSignal.any([request.signal, timeout]);
      try {
        const response = await fetchImpl(endpoint, {
          method: 'POST',
          signal,
          headers: {
            'content-type': 'application/json',
            'x-api-key': config.apiKey,
            'anthropic-version': apiVersion,
          },
          body: JSON.stringify({
            model: request.model,
            max_tokens: request.maxTokens,
            stream: true,
            system: request.system,
            messages: [{ role: 'user', content: request.user }],
          }),
        });
        if (response.ok && response.body !== null) return response;
        await response.body?.cancel().catch(() => undefined);
        lastError = isRetryableStatus(response.status)
          ? new LlmError('LLM_UNAVAILABLE', true)
          : new LlmError('LLM_REJECTED', false);
      } catch (error) {
        if (error instanceof LlmError) throw error;
        lastError = new LlmError(
          timeout.aborted ? 'LLM_TIMEOUT' : 'LLM_UNAVAILABLE',
          !callerAborted(),
        );
      }
      if (!lastError.retryable || attempt === maxAttempts) break;
      await sleep(baseDelayMs * 2 ** (attempt - 1));
    }
    throw lastError;
  }

  return {
    async *stream(request) {
      const response = await open(request);
      const reader = (response.body as ReadableStream<Uint8Array>).getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      try {
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true }).replaceAll('\r\n', '\n');
          let boundary = buffer.indexOf('\n\n');
          while (boundary !== -1) {
            const event = toEvent(parseSseData(buffer.slice(0, boundary)));
            buffer = buffer.slice(boundary + 2);
            if (event !== undefined) yield event;
            boundary = buffer.indexOf('\n\n');
          }
        }
      } catch {
        throw new LlmError('LLM_UNAVAILABLE', false);
      } finally {
        await reader.cancel().catch(() => undefined);
      }
    },
  };
}

import { models } from '../config/models.js';
import { LlmError } from '../llm/types.js';
import type { LlmProvider, LlmUsage } from '../llm/types.js';
import { loadPrompt } from './prompts.js';
import { parseInsightCard } from './schemas.js';
import type { InsightCard, InsightRequest } from './schemas.js';

export interface InsightResult {
  readonly card: InsightCard;
  readonly model: string;
  readonly usage: LlmUsage;
}

export class InsightError extends Error {
  constructor(readonly code: 'INSIGHT_INVALID_OUTPUT' | 'INSIGHT_UNAVAILABLE') {
    super(code);
    this.name = 'InsightError';
  }
}

const maxOutputTokens = 400;

async function collect(
  provider: LlmProvider,
  model: string,
  request: InsightRequest,
  signal: AbortSignal | undefined,
): Promise<{ text: string; usage: LlmUsage }> {
  // Transcript and profile are untrusted data: JSON-encoded, never concatenated into the system prompt.
  const user = JSON.stringify({
    language: request.language,
    trigger: request.trigger,
    transcript_window: request.transcriptWindow,
    ...(request.profile === undefined ? {} : { profile: request.profile }),
  });
  let text = '';
  let inputTokens = 0;
  let outputTokens = 0;
  for await (const event of provider.stream({
    model,
    system: loadPrompt('live-insight.v1'),
    user,
    maxTokens: maxOutputTokens,
    ...(signal === undefined ? {} : { signal }),
  })) {
    if (event.type === 'delta' && event.text !== undefined) text += event.text;
    if (event.type === 'usage' && event.usage !== undefined) {
      inputTokens = Math.max(inputTokens, event.usage.inputTokens);
      outputTokens = Math.max(outputTokens, event.usage.outputTokens);
    }
  }
  return { text, usage: { inputTokens, outputTokens } };
}

/**
 * Generates one validated insight card. The default model is tried first. Provider failures fall
 * back to the cheaper model once. Invalid model output is never forwarded to clients.
 */
export async function generateInsight(
  provider: LlmProvider,
  request: InsightRequest,
  signal?: AbortSignal,
): Promise<InsightResult> {
  const candidates = [models.liveInsight, models.liveInsightFallback];
  for (const model of candidates) {
    try {
      const { text, usage } = await collect(provider, model, request, signal);
      let parsed: unknown;
      try {
        parsed = JSON.parse(text.trim());
      } catch {
        throw new InsightError('INSIGHT_INVALID_OUTPUT');
      }
      const card = parseInsightCard(parsed);
      if (card === undefined) throw new InsightError('INSIGHT_INVALID_OUTPUT');
      return { card, model, usage };
    } catch (error) {
      if (signal?.aborted === true) throw new InsightError('INSIGHT_UNAVAILABLE');
      if (error instanceof InsightError) throw error;
      if (!(error instanceof LlmError)) throw new InsightError('INSIGHT_UNAVAILABLE');
    }
  }
  throw new InsightError('INSIGHT_UNAVAILABLE');
}

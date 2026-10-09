import type { LanguageGenerator, TokenUsage } from '../llm/contracts.js';
import { GenerationError } from '../llm/contracts.js';
import type { LiveInsight, TriggerClassification } from './output.js';
import { validateInsightOutput, validateTriggerOutput } from './output.js';
import { loadPromptContract } from './prompts.js';

export interface InsightInput {
  readonly consentConfirmed: true;
  readonly language: 'en' | 'tr';
  readonly trigger: 'question' | 'objection' | 'term';
  readonly transcriptWindow: string;
  readonly profile?: string;
}

export function parseInsightInput(value: unknown): InsightInput | undefined {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return undefined;
  const body = value as Record<string, unknown>;
  const allowed = ['consentConfirmed', 'language', 'trigger', 'transcriptWindow', 'profile'];
  if (
    Object.keys(body).some((key) => !allowed.includes(key)) ||
    body.consentConfirmed !== true ||
    (body.language !== 'en' && body.language !== 'tr') ||
    (body.trigger !== 'question' && body.trigger !== 'objection' && body.trigger !== 'term') ||
    typeof body.transcriptWindow !== 'string' ||
    body.transcriptWindow.trim() === '' ||
    body.transcriptWindow.length > 12_000 ||
    (body.profile !== undefined && (typeof body.profile !== 'string' || body.profile.length > 1000))
  )
    return undefined;
  const input: InsightInput = {
    consentConfirmed: true,
    language: body.language,
    trigger: body.trigger,
    transcriptWindow: body.transcriptWindow,
    ...(typeof body.profile === 'string' ? { profile: body.profile } : {}),
  };
  if (JSON.stringify(input).length > 24_576) return undefined;
  return input;
}

export type InsightEvent =
  | { readonly type: 'progress'; readonly receivedCharacters: number }
  | { readonly type: 'card'; readonly card: LiveInsight; readonly promptVersion: string }
  | {
      readonly type: 'completed';
      readonly model: string;
      readonly attempts: number;
      readonly usage: TokenUsage;
    };

export type InsightGenerator = (
  input: InsightInput,
  signal: AbortSignal,
) => AsyncIterable<InsightEvent>;

export function createInsightGenerator(generate: LanguageGenerator): InsightGenerator {
  return async function* (input, signal) {
    const prompt = await loadPromptContract('liveInsight');
    signal.throwIfAborted();
    let output = '';
    let reported = 0;
    for await (const event of generate({
      task: 'liveInsight',
      systemPrompt: prompt.systemPrompt,
      signal,
      input: JSON.stringify({
        language: input.language,
        trigger: input.trigger,
        transcript_window: input.transcriptWindow,
        profile: input.profile ?? '',
      }),
    })) {
      signal.throwIfAborted();
      if (event.type === 'text') {
        output += event.text;
        if (output.length > 16_384) throw new GenerationError('invalid_response');
        if (output.length - reported >= 128) {
          reported = output.length;
          yield { type: 'progress', receivedCharacters: reported };
        }
      } else {
        // Account for completed provider usage even when its JSON fails validation.
        yield event;
        const card = validateInsightOutput(output, prompt.schema);
        yield { type: 'card', card, promptVersion: prompt.version };
        return;
      }
    }
    throw new GenerationError('invalid_response');
  };
}

export async function classifyTrigger(
  generate: LanguageGenerator,
  language: 'en' | 'tr',
  transcript: string,
  signal: AbortSignal,
): Promise<TriggerClassification> {
  if (transcript.trim() === '' || transcript.length > 4000)
    throw new GenerationError('invalid_response');
  const prompt = await loadPromptContract('triggerClassification');
  let output = '';
  for await (const event of generate({
    task: 'triggerClassification',
    systemPrompt: prompt.systemPrompt,
    input: JSON.stringify({ language, transcript }),
    signal,
  })) {
    signal.throwIfAborted();
    if (event.type === 'text') {
      output += event.text;
      if (output.length > 4096) throw new GenerationError('invalid_response');
    } else {
      return validateTriggerOutput(output, prompt.schema, transcript);
    }
  }
  throw new GenerationError('invalid_response');
}

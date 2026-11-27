import { models } from '../config/models.js';
import type { LlmProvider, LlmUsage } from '../llm/types.js';
import { InsightError } from './generate-insight.js';
import { loadPrompt } from './prompts.js';
import { parseTriggerClassification } from './schemas.js';
import type { ClassifyRequest, TriggerClassification } from './schemas.js';

export interface ClassifyResult {
  readonly classification: TriggerClassification;
  readonly model: string;
  readonly usage: LlmUsage;
}

const maxOutputTokens = 120;

/**
 * Stage 2 trigger classification with the small model. There is deliberately no model fallback:
 * when this fails the client keeps its stage 1 (local lexicon) decision, so a failure only costs
 * the ambiguous case, never a live meeting.
 */
export async function classifyTrigger(
  provider: LlmProvider,
  request: ClassifyRequest,
  signal?: AbortSignal,
): Promise<ClassifyResult> {
  const model = models.triggerClassification;
  let text = '';
  let inputTokens = 0;
  let outputTokens = 0;
  try {
    for await (const event of provider.stream({
      model,
      system: loadPrompt('trigger-classifier.v1'),
      // Untrusted excerpt is JSON-encoded data, never part of the instructions.
      user: JSON.stringify({ language: request.language, transcript: request.transcript }),
      maxTokens: maxOutputTokens,
      ...(signal === undefined ? {} : { signal }),
    })) {
      if (event.type === 'delta' && event.text !== undefined) text += event.text;
      if (event.type === 'usage' && event.usage !== undefined) {
        inputTokens = Math.max(inputTokens, event.usage.inputTokens);
        outputTokens = Math.max(outputTokens, event.usage.outputTokens);
      }
    }
  } catch {
    throw new InsightError('INSIGHT_UNAVAILABLE');
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text.trim());
  } catch {
    throw new InsightError('INSIGHT_INVALID_OUTPUT');
  }
  const classification = parseTriggerClassification(parsed);
  if (classification === undefined) throw new InsightError('INSIGHT_INVALID_OUTPUT');
  // Evidence must be copied from the input. Anything else is treated as invalid model output.
  if (classification.evidence !== '' && !request.transcript.includes(classification.evidence)) {
    throw new InsightError('INSIGHT_INVALID_OUTPUT');
  }
  return { classification, model, usage: { inputTokens, outputTokens } };
}

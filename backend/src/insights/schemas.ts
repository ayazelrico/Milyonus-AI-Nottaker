export type InsightLanguage = 'en' | 'tr';
export type InsightTrigger = 'question' | 'objection' | 'term';

export interface InsightRequest {
  readonly language: InsightLanguage;
  readonly trigger: InsightTrigger;
  readonly transcriptWindow: string;
  readonly profile?: string;
}

export interface InsightCard {
  readonly status: 'suggestion' | 'insufficient_evidence';
  readonly title: string;
  readonly body: string;
  readonly confidence: number;
  readonly citations: readonly string[];
}

export interface TriggerClassification {
  readonly label: 'question' | 'objection' | 'term' | 'none';
  readonly confidence: number;
  readonly evidence: string;
}

export interface ClassifyRequest {
  readonly language: InsightLanguage;
  readonly transcript: string;
}

export const maxClassifyTranscriptLength = 1_000;
export const maxTranscriptWindowLength = 8_000;
export const maxProfileLength = 500;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function hasExactKeys(record: Record<string, unknown>, keys: readonly string[]): boolean {
  const actual = Object.keys(record);
  return actual.length === keys.length && keys.every((key) => key in record);
}

function isConfidence(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1;
}

/** Validates the client request. Unknown keys are rejected so nothing unexpected reaches a prompt. */
export function parseInsightRequest(body: unknown): InsightRequest | undefined {
  if (!isRecord(body)) return undefined;
  const allowed = new Set(['language', 'trigger', 'transcriptWindow', 'profile']);
  if (Object.keys(body).some((key) => !allowed.has(key))) return undefined;
  const { language, trigger, transcriptWindow, profile } = body;
  if (language !== 'en' && language !== 'tr') return undefined;
  if (trigger !== 'question' && trigger !== 'objection' && trigger !== 'term') return undefined;
  if (
    typeof transcriptWindow !== 'string' ||
    transcriptWindow.trim().length === 0 ||
    transcriptWindow.length > maxTranscriptWindowLength
  ) {
    return undefined;
  }
  if (profile !== undefined && (typeof profile !== 'string' || profile.length > maxProfileLength)) {
    return undefined;
  }
  return profile === undefined
    ? { language, trigger, transcriptWindow }
    : { language, trigger, transcriptWindow, profile };
}

/** Mirrors prompts/schemas/live-insight.v1.json. */
export function parseInsightCard(value: unknown): InsightCard | undefined {
  if (
    !isRecord(value) ||
    !hasExactKeys(value, ['status', 'title', 'body', 'confidence', 'citations'])
  ) {
    return undefined;
  }
  const { status, title, body, confidence, citations } = value;
  if (status !== 'suggestion' && status !== 'insufficient_evidence') return undefined;
  if (typeof title !== 'string' || title.length > 120) return undefined;
  if (typeof body !== 'string' || body.length > 600) return undefined;
  if (!isConfidence(confidence)) return undefined;
  // Citations stay empty until retrieval (P4-06) supplies stable IDs.
  if (!Array.isArray(citations) || citations.length !== 0) return undefined;
  return { status, title, body, confidence, citations: [] };
}

/** Mirrors prompts/schemas/trigger-classifier.v1.json. */
export function parseTriggerClassification(value: unknown): TriggerClassification | undefined {
  if (!isRecord(value) || !hasExactKeys(value, ['label', 'confidence', 'evidence']))
    return undefined;
  const { label, confidence, evidence } = value;
  if (label !== 'question' && label !== 'objection' && label !== 'term' && label !== 'none') {
    return undefined;
  }
  if (!isConfidence(confidence)) return undefined;
  if (typeof evidence !== 'string' || evidence.length > 240) return undefined;
  return { label, confidence, evidence };
}

/** Validates the stage 2 classification request. The excerpt is short by design (latency and cost). */
export function parseClassifyRequest(body: unknown): ClassifyRequest | undefined {
  if (!isRecord(body) || !hasExactKeys(body, ['language', 'transcript'])) return undefined;
  const { language, transcript } = body;
  if (language !== 'en' && language !== 'tr') return undefined;
  if (
    typeof transcript !== 'string' ||
    transcript.trim().length === 0 ||
    transcript.length > maxClassifyTranscriptLength
  ) {
    return undefined;
  }
  return { language, transcript };
}

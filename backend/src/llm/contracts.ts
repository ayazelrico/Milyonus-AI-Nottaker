export type GenerationTask = 'triggerClassification' | 'liveInsight';

export interface GenerationInput {
  readonly task: GenerationTask;
  readonly systemPrompt: string;
  readonly input: string;
  readonly signal: AbortSignal;
}

export interface TokenUsage {
  readonly inputTokens: number;
  readonly outputTokens: number;
  readonly cacheReadTokens: number;
  readonly cacheCreationTokens: number;
}

export type GenerationEvent =
  | { readonly type: 'text'; readonly text: string }
  | {
      readonly type: 'completed';
      readonly model: string;
      readonly attempts: number;
      readonly usage: TokenUsage;
    };

export type LanguageGenerator = (input: GenerationInput) => AsyncIterable<GenerationEvent>;

export class GenerationError extends Error {
  constructor(
    readonly code: 'unavailable' | 'invalid_response' | 'cancelled' | 'timeout',
    readonly retryable = false,
  ) {
    super(`Generation failed: ${code}`);
    this.name = 'GenerationError';
  }
}

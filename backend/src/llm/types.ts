export interface LlmRequest {
  readonly model: string;
  readonly system: string;
  /** Untrusted user content. Callers pass JSON-encoded data, never instructions. */
  readonly user: string;
  readonly maxTokens: number;
  readonly signal?: AbortSignal;
}

export interface LlmUsage {
  readonly inputTokens: number;
  readonly outputTokens: number;
}

export interface LlmStreamEvent {
  readonly type: 'delta' | 'usage';
  readonly text?: string;
  readonly usage?: LlmUsage;
}

/** Provider boundary. Swapping providers or a local model only needs another implementation. */
export interface LlmProvider {
  stream(request: LlmRequest): AsyncIterable<LlmStreamEvent>;
}

export class LlmError extends Error {
  constructor(
    readonly code: 'LLM_TIMEOUT' | 'LLM_UNAVAILABLE' | 'LLM_REJECTED',
    readonly retryable: boolean,
  ) {
    super(code);
    this.name = 'LlmError';
  }
}

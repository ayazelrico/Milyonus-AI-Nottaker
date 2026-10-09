/** Provider model names are centralized here; calls require the development insight gate. */
export const models = Object.freeze({
  triggerClassification: 'claude-haiku-4-5-20251001',
  liveInsight: 'claude-sonnet-5-5',
  liveInsightFallback: 'claude-haiku-4-5-20251001',
  postMeeting: 'claude-opus-5-5',
  preCallBrief: 'claude-opus-5-5',
});

/** Sonnet 5.5 requires between_tools for text-only latency-sensitive calls. */
export const generationOptions = Object.freeze({
  [models.liveInsight]: Object.freeze({
    thinking: Object.freeze({ type: 'between_tools' }),
    output_config: Object.freeze({ effort: 'low' }),
  }),
  [models.triggerClassification]: Object.freeze({
    thinking: Object.freeze({ type: 'disabled' }),
  }),
});

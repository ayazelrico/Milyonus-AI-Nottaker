# 07 - Prompts and evaluations

Production prompts belong in prompts/ with versioned filenames, schemas, and a changelog. Never
inline them into Swift or TypeScript. There are no production prompt files in Phase 0 because the
foundation makes no model calls.

Each prompt change requires evals on synthetic or licensed examples, including EN and TR where
supported. Record model ID/configuration, prompt version, dataset version, quality measures, latency,
and usage counts. Do not log private transcripts or model request bodies.

Required suites: trigger classification, relevance, source grounding, prompt injection resistance,
summary/action recall and precision, refusal to invent owners/dates, and malformed/partial output.
Dataset revisions must preserve a holdout set. A failing safety/grounding gate blocks release even
when aggregate quality improves. Define exact thresholds in the feature spec before implementation.

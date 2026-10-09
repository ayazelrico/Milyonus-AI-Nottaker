import { GenerationError } from '../llm/contracts.js';

type ObjectValue = Record<string, unknown>;

function object(value: unknown): value is ObjectValue {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

const keywords = new Set([
  '$schema',
  'type',
  'additionalProperties',
  'required',
  'properties',
  'enum',
  'minimum',
  'maximum',
  'maxLength',
  'maxItems',
  'items',
]);

/** Validate only the explicit schema vocabulary used by our versioned prompt contracts. */
export function matchesOutputSchema(value: unknown, schema: unknown): boolean {
  if (!object(schema) || Object.keys(schema).some((key) => !keywords.has(key))) return false;
  if (schema.enum !== undefined && (!Array.isArray(schema.enum) || !schema.enum.includes(value))) {
    return false;
  }
  if (schema.type === undefined) return Array.isArray(schema.enum);
  switch (schema.type) {
    case 'object': {
      if (
        !object(value) ||
        !object(schema.properties) ||
        !Array.isArray(schema.required) ||
        schema.additionalProperties !== false
      )
        return false;
      const properties = schema.properties;
      return (
        schema.required.every(
          (key: unknown) => typeof key === 'string' && Object.hasOwn(value, key),
        ) &&
        Object.keys(value).every(
          (key) =>
            Object.hasOwn(properties, key) && matchesOutputSchema(value[key], properties[key]),
        )
      );
    }
    case 'number':
      return (
        typeof value === 'number' &&
        Number.isFinite(value) &&
        (schema.minimum === undefined ||
          (typeof schema.minimum === 'number' && value >= schema.minimum)) &&
        (schema.maximum === undefined ||
          (typeof schema.maximum === 'number' && value <= schema.maximum))
      );
    case 'string':
      return (
        typeof value === 'string' &&
        (schema.maxLength === undefined ||
          (typeof schema.maxLength === 'number' && Array.from(value).length <= schema.maxLength))
      );
    case 'array':
      return (
        Array.isArray(value) &&
        (schema.maxItems === undefined ||
          (typeof schema.maxItems === 'number' && value.length <= schema.maxItems)) &&
        value.every((item: unknown) => matchesOutputSchema(item, schema.items))
      );
    default:
      return false;
  }
}

export interface TriggerClassification {
  readonly label: 'question' | 'objection' | 'term' | 'none';
  readonly confidence: number;
  readonly evidence: string;
}

export interface LiveInsight {
  readonly status: 'suggestion' | 'insufficient_evidence';
  readonly title: string;
  readonly body: string;
  readonly confidence: number;
  readonly citations: readonly string[];
}

function parsedOutput(text: string, schema: unknown): ObjectValue {
  if (text.length > 16_384) throw new GenerationError('invalid_response');
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new GenerationError('invalid_response');
  }
  if (!object(value) || !matchesOutputSchema(value, schema)) {
    throw new GenerationError('invalid_response');
  }
  return value;
}

export function validateTriggerOutput(
  text: string,
  schema: unknown,
  transcript: string,
): TriggerClassification {
  const value = parsedOutput(text, schema) as unknown as TriggerClassification;
  if (
    value.label === 'none'
      ? value.evidence !== ''
      : value.evidence.trim() === '' || !transcript.includes(value.evidence)
  ) {
    throw new GenerationError('invalid_response');
  }
  return Object.freeze({ ...value });
}

export function validateInsightOutput(text: string, schema: unknown): LiveInsight {
  const value = parsedOutput(text, schema) as unknown as LiveInsight;
  if (value.title.trim() === '' || value.body.trim() === '' || value.citations.length !== 0) {
    throw new GenerationError('invalid_response');
  }
  return Object.freeze({ ...value, citations: Object.freeze([]) });
}

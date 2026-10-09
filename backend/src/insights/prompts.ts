import { readFile, stat } from 'node:fs/promises';
import type { GenerationTask } from '../llm/contracts.js';
import { GenerationError } from '../llm/contracts.js';

export interface PromptContract {
  readonly version: string;
  readonly systemPrompt: string;
  readonly schema: unknown;
}

const filenames = Object.freeze({
  triggerClassification: 'trigger-classifier.v1',
  liveInsight: 'live-insight.v1',
});
const root = new URL('../../../prompts/', import.meta.url);

async function boundedFile(url: URL): Promise<string> {
  if ((await stat(url)).size > 32_768) throw new GenerationError('unavailable');
  return readFile(url, 'utf8');
}

/** Only allowlisted repository prompts are loaded. No request-supplied path is accepted. */
export async function loadPromptContract(task: GenerationTask): Promise<PromptContract> {
  try {
    const name = filenames[task];
    const [systemPrompt, schemaText] = await Promise.all([
      boundedFile(new URL(`${name}.md`, root)),
      boundedFile(new URL(`schemas/${name}.json`, root)),
    ]);
    const schema: unknown = JSON.parse(schemaText);
    if (systemPrompt.trim() === '') throw new GenerationError('unavailable');
    return Object.freeze({ version: name, systemPrompt, schema });
  } catch {
    throw new GenerationError('unavailable');
  }
}

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/** Prompts live in the repository `prompts/` directory and are versioned (AGENTS.md rule 6). */
const promptsDirectory = resolve(import.meta.dirname, '../../../prompts');

const cache = new Map<string, string>();

export function loadPrompt(name: 'live-insight.v1' | 'trigger-classifier.v1'): string {
  const cached = cache.get(name);
  if (cached !== undefined) return cached;
  const text = readFileSync(resolve(promptsDirectory, `${name}.md`), 'utf8');
  cache.set(name, text);
  return text;
}

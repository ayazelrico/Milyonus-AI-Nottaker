import { resolve } from 'node:path';
import { config as loadEnvironmentFile } from 'dotenv';
import { buildApp } from './app.js';
import { parseConfig } from './config/env.js';
import { writeOperationalEvent } from './observability.js';

async function start(): Promise<void> {
  const loaded = loadEnvironmentFile({
    path: resolve(import.meta.dirname, '../.env.local'),
    quiet: true,
    override: false,
  });
  if (loaded.error !== undefined && (loaded.error as NodeJS.ErrnoException).code !== 'ENOENT') {
    throw new Error('Environment file could not be loaded');
  }

  const config = parseConfig(process.env);
  const app = buildApp(config);
  let closing = false;
  const shutdown = (): void => {
    if (closing) return;
    closing = true;
    void app.close().catch(() => {
      writeOperationalEvent({ event: 'shutdown_failed' });
      process.exitCode = 1;
    });
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);

  await app.listen({ host: config.host, port: config.port });
  writeOperationalEvent({ event: 'server_started', port: config.port });
}

void start().catch(() => {
  writeOperationalEvent({ event: 'startup_failed' });
  process.exitCode = 1;
});

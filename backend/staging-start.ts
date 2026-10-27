// Explicit Render closed-test entry point. Validate before any writes or bind.
import { serverConfig } from './src/server/config';
import { migrateNative } from '../db/migrate-native';
try {
  process.env.BEEF_PORT = process.env.PORT ?? process.env.BEEF_PORT;
  serverConfig(process.env);
  await migrateNative();
  await import('./serve');
} catch {
  console.error('Closed-test startup failed; service not started');
  process.exitCode = 1;
}

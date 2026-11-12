// Explicit Render closed-test entry point. Validate before any writes or bind.
import { startupDiagnostic } from './src/server/startup-diagnostic';
import { serverConfig } from './src/server/config';
import { migrateNative } from '../db/migrate-native';
let stage = 'configuration';
try {
  process.env.BEEF_PORT = process.env.PORT ?? process.env.BEEF_PORT;
  serverConfig(process.env);
  stage = 'migrations';
  await migrateNative();
  stage = 'server';
  await import('./serve');
} catch (error) {
  console.error(`Closed-test startup failed: ${stage}/${startupDiagnostic(error)}; service not started`);
  process.exitCode = 1;
}

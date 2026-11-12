import { neon } from '@neondatabase/serverless';
import { nativeDatabase, type Database } from './native-db';

/** Server-only, lazy configuration. Neon HTTP remains the backwards-compatible default. */
export const sql = (): Database => {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is required');
  const driver = process.env.BEEF_DATABASE_DRIVER ?? 'neon';
  if (driver === 'postgres') return nativeDatabase(url);
  if (driver !== 'neon') throw new Error('Invalid BEEF_DATABASE_DRIVER');
  return neon(url) as unknown as Database;
};

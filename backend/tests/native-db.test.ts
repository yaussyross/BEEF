import { expect, test } from 'bun:test';
import { nativeOptions, postgresArray } from '../src/native-db';
test('native PostgreSQL verifies TLS by default and never silently downgrades', () => {
  expect(nativeOptions('postgres://fixture@localhost/test').tls).toEqual({ rejectUnauthorized: true });
  expect(nativeOptions('postgres://fixture@localhost/test?sslmode=disable').tls).toBe(false);
  for (const mode of ['require', 'prefer', 'allow', 'typo']) {
    expect(() => nativeOptions(`postgres://fixture@localhost/test?sslmode=${mode}`)).toThrow();
  }
  expect(() => nativeOptions('postgres://fixture@localhost/test?ssl=false')).toThrow();
  expect(() => nativeOptions('https://fixture.test')).toThrow('Invalid DATABASE_URL');
});

test('PostgreSQL arrays preserve null, quotes, commas and backslashes as bound values', () => {
  expect(postgresArray(['one', 'a,b', null, 'NULL'])).toBe('{"one","a,b",NULL,"NULL"}');
  expect(postgresArray(['a"b'])).toBe('{"a\\"b"}');
  expect(() => postgresArray([{}])).toThrow();
});

test('Render internal TLS opt-in requires a private hostname and never permits plaintext flags', () => {
  expect(nativeOptions('postgres://fixture@dpg-synthetic-a/test', 'render_internal').tls).toEqual({ rejectUnauthorized: false });
  for (const url of ['postgres://fixture@public.example/test', 'postgres://fixture@dpg-fixture.oregon-postgres.render.com/test', 'postgres://fixture@dpg-fixture/test?sslmode=disable']) {
    expect(() => nativeOptions(url, 'render_internal')).toThrow();
  }
  expect(() => nativeOptions('postgres://fixture@localhost/test', 'typo')).toThrow();
});

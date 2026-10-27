import { expect, test } from 'bun:test';
import { closedTestPolicy } from '../src/lib/closed-test';
test('closed test is default and missing, malformed or wildcard configuration fails closed', () => {
  for (const env of [{}, { BEEF_ACCESS_MODE: 'typo' }, { BEEF_CLOSED_TEST_EMAILS: '' },
    { BEEF_CLOSED_TEST_EMAILS: '*@example.test' }, { BEEF_CLOSED_TEST_EMAILS: 'a@example.test,' }]) {
    expect(() => closedTestPolicy(env)).toThrow('Test access is unavailable.');
  }
});
test('allowlist uses complete normalized addresses, never domains or substrings', () => {
  const policy = closedTestPolicy({ BEEF_CLOSED_TEST_EMAILS: ' Fixture-A@Example.Test,fixture-b@example.test ' });
  expect(policy.closed).toBe(true);
  expect(policy.emails.has('fixture-a@example.test')).toBe(true);
  expect(policy.emails.has('outsider@example.test')).toBe(false);
  expect(policy.emails.has('fixture-a@example.test.attacker.test')).toBe(false);
  expect(closedTestPolicy({ BEEF_ACCESS_MODE: 'open' }).closed).toBe(false);
});

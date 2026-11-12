/** Bounded, process-local private-test defense; not a distributed production limiter. */
export function createLoginThrottle(now: () => number = Date.now) {
  let until = 0;
  let total = 0;
  const accounts = new Map<string, number>();
  return (email: string): number => {
    const time = now();
    if (time >= until) { until = time + 60_000; total = 0; accounts.clear(); }
    const retry = Math.max(1, Math.ceil((until - time) / 1000));
    if (total >= 100) return retry;
    total++;
    const key = email.trim().toLowerCase();
    const count = accounts.get(key) ?? 0;
    if (count >= 10) return retry;
    accounts.set(key, count + 1);
    return 0;
  };
}
export const loginThrottle = createLoginThrottle();

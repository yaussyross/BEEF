/** Native PostgreSQL adapter for the small tagged-query surface used by BEEF.
 * Queries stay lazy until awaited or claimed by one sequential transaction.
 */
type Row = Record<string, any>;
export interface PendingQuery extends PromiseLike<Row[]> {}
export interface Database {
  (strings: TemplateStringsArray, ...values: unknown[]): PendingQuery;
  query(text: string, values?: unknown[], options?: { fetchOptions?: { signal?: AbortSignal } }): PendingQuery;
  transaction(queries: PendingQuery[]): Promise<Row[][]>;
}
// Bun's unsafe parameter binding stringifies JS arrays as comma-separated text;
// encode a PostgreSQL array value, still bound as a parameter (never SQL text).
export function postgresArray(values: unknown[]): string {
  return '{' + values.map(value => {
    if (value === null) return 'NULL';
    if (Array.isArray(value)) return postgresArray(value);
    if (!['string', 'number', 'boolean'].includes(typeof value)) throw new Error('Unsupported database array value');
    return '"' + String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
  }).join(',') + '}';
}
type Executor = Pick<Bun.SQL, 'unsafe'>;
function normalize(value: any): any {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === 'object' && !(value instanceof Uint8Array)) {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalize(v)]));
  }
  return value;
}
export function nativeOptions(raw: string, tlsPolicy = process.env.BEEF_DATABASE_TLS ?? 'verified') {
  let url: URL;
  try { url = new URL(raw); } catch { throw new Error('Invalid DATABASE_URL'); }
  if (!['postgres:', 'postgresql:'].includes(url.protocol)) throw new Error('Invalid DATABASE_URL');
  if (url.searchParams.has('ssl') || url.searchParams.has('tls')) throw new Error('Use sslmode for native PostgreSQL TLS configuration');
  if (!['verified', 'render_internal'].includes(tlsPolicy)) throw new Error('Invalid BEEF_DATABASE_TLS');
  if (tlsPolicy === 'render_internal') {
    // Render internal endpoints use self-signed certificates. Explicit opt-in,
    // internal-only hostname and mandatory TLS; never a public endpoint fallback.
    if (!/^dpg-[a-z0-9-]+$/.test(url.hostname) || url.searchParams.has('sslmode')) {
      throw new Error('Render internal TLS requires an unmodified internal database URL');
    }
    return { url: url.href, tls: { rejectUnauthorized: false }, max: 5, idleTimeout: 20, connectionTimeout: 5 };
  }
  const mode = url.searchParams.get('sslmode') ?? 'verify-full';
  if (!['verify-full', 'disable'].includes(mode)) throw new Error('Native PostgreSQL requires sslmode=verify-full or explicit disable');
  url.searchParams.delete('sslmode');
  // No insecure certificate fallback. Explicit disable is for an approved local/private transport only.
  return { url: url.href, tls: mode === 'disable' ? false as const : { rejectUnauthorized: true },
    max: 5, idleTimeout: 20, connectionTimeout: 5 };
}
const poolsKey = Symbol.for('beef.native-postgres.pools');
function pools(): Map<string, Bun.SQL> {
  const g = globalThis as typeof globalThis & { [poolsKey]?: Map<string, Bun.SQL> };
  return g[poolsKey] ??= new Map();
}
export async function closeNativeDatabases(): Promise<void> {
  const current = [...pools().values()]; pools().clear();
  await Promise.all(current.map(pool => pool.close({ timeout: 1 })));
}
function poolFor(url: string, probe = false): { key: string; pool: Bun.SQL } {
  const key = JSON.stringify([url, probe, process.env.BEEF_DATABASE_TLS ?? 'verified']);
  let pool = pools().get(key);
  if (!pool) {
    const options = nativeOptions(url);
    pool = new Bun.SQL(options.url, { ...options, max: probe ? 1 : options.max,
      ...(probe ? { connection: { statement_timeout: 2000 } } : {}) });
    pools().set(key, pool);
  }
  return { key, pool };
}
export function nativeDatabase(url: string): Database {
  const owner = poolFor(url).pool;
  class Query implements PendingQuery {
    private started = false;
    private promise?: Promise<Row[]>;
    constructor(readonly text: string, readonly values: unknown[], readonly signal?: AbortSignal) {}
    take() {
      if (this.started) throw new Error('Database query was already consumed');
      this.started = true;
      return this;
    }
    async execute(executor: Executor): Promise<Row[]> {
      this.signal?.throwIfAborted();
      // Abortable readiness probes get a separate bounded connection. Bun 1.3
      // cancel() alone can wait for SQL completion; never tie up the app pool.
      const probe = this.signal ? poolFor(url, true) : undefined;
      const query = (probe?.pool ?? executor).unsafe(this.text, this.values.map(value => Array.isArray(value) ? postgresArray(value) : value));
      let rejectAbort: (error: Error) => void = () => {};
      const aborted = new Promise<never>((_, reject) => { rejectAbort = reject; });
      const cancel = () => {
        try { query.cancel(); } catch { /* pool close still enforces failure */ }
        if (probe) {
          if (pools().get(probe.key) === probe.pool) pools().delete(probe.key);
          void probe.pool.close({ timeout: 0 }).catch(() => {});
        }
        rejectAbort(new Error('Database query aborted'));
      };
      this.signal?.addEventListener('abort', cancel, { once: true });
      try {
        const rows = await (this.signal ? Promise.race([query, aborted]) : query);
        this.signal?.throwIfAborted();
        return normalize(rows);
      }
      catch (error) {
        const source = error as { message?: string; constraint?: string };
        // Do not expose SQL, parameters, database addresses or driver diagnostics.
        const safe = new Error(source.message?.includes('users_assert_adult') ? 'users_assert_adult' : 'Database query failed');
        if (['message_safety_hold', 'profile_ratings_eligible', 'report_request_conflict'].includes(source.constraint ?? '')) {
          Object.assign(safe, { constraint: source.constraint });
        }
        throw safe;
      }
      finally { this.signal?.removeEventListener('abort', cancel); }
    }
    then<TResult1 = Row[], TResult2 = never>(
      fulfilled?: ((value: Row[]) => TResult1 | PromiseLike<TResult1>) | null,
      rejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null,
    ): Promise<TResult1 | TResult2> {
      if (!this.promise) {
        try { this.take(); this.promise = this.execute(owner); }
        catch (error) { this.promise = Promise.reject(error); }
      }
      return this.promise.then(fulfilled, rejected);
    }
  }
  const db = ((strings: TemplateStringsArray, ...values: unknown[]) => {
    const text = strings.reduce((s, part, i) => s + (i ? `$${i}` : '') + part, '');
    return new Query(text, values);
  }) as unknown as Database;
  db.query = (text, values = [], options) => new Query(text, values, options?.fetchOptions?.signal);
  db.transaction = async queries => {
    if (queries.some(q => !(q instanceof Query))) throw new Error('Transaction query belongs to another database handle');
    const batch = (queries as Query[]).map(q => q.take());
    try { return await owner.begin(async tx => {
      const results: Row[][] = [];
      for (const query of batch) results.push(await query.execute(tx));
      return results;
    }); } catch (error) {
      if (error instanceof Error && (error.message === 'Database query failed' || error.message === 'users_assert_adult')) throw error;
      throw new Error('Database transaction failed');
    }
  };
  return db;
}

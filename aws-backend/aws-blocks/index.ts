import {
  ApiNamespace,
  Scope,
  AuthBasic,
  DistributedTable,
} from '@aws-blocks/blocks';
import crypto from 'node:crypto';
import { z } from 'zod';

// Kimchi Jarvis backend, built with AWS Blocks.
//
// Locally (`npm run dev`) every Block uses an in-memory/mock implementation, so
// this runs with no AWS account. On `npm run sandbox` / `npm run deploy` the
// same code provisions real AWS resources:
//   - AuthBasic          -> Amazon DynamoDB (user records) + JWT sessions
//   - DistributedTable   -> Amazon DynamoDB (per-user saved history)
//   - ApiNamespace       -> Amazon API Gateway + AWS Lambda (JSON-RPC endpoint)
const scope = new Scope('kimchi-jarvis');

// Username/password auth with JWT sessions. `crossDomain: true` because the
// Flutter frontend is hosted on a different domain (Vercel) from this API
// (AWS), so the session cookie must be SameSite=None; Secure; Partitioned.
// Upgrade path: swap `AuthBasic` for `AuthCognito` (same interface) to get
// managed Cognito with MFA, groups and social sign-in.
const auth = new AuthBasic(scope, 'auth', {
  sessionDuration: 60 * 60 * 24 * 7, // 7 days
  crossDomain: true,
  passwordPolicy: { minLength: 8 },
});

// Per-user saved history (each translation or Kimchi exchange the user keeps).
const historySchema = z.object({
  userId: z.string(),
  entryId: z.string(),
  mode: z.string(), // 'translate' | 'companion'
  original: z.string(),
  output: z.string(),
  sourceLang: z.string(),
  targetLang: z.string(),
  createdAt: z.number(),
});

const history = new DistributedTable(scope, 'history', {
  schema: historySchema,
  key: { partitionKey: 'userId', sortKey: 'entryId' },
  indexes: {
    byCreatedAt: { partitionKey: 'userId', sortKey: 'createdAt' },
  },
});

// State-machine API that also powers web Authenticator components (unused by
// the Flutter client, which calls the explicit methods below).
export const authApi = auth.createApi();

export const api = new ApiNamespace(scope, 'api', (context) => ({
  // ── Health check (public) ────────────────────────────────────────────
  async ping() {
    return { message: 'pong', timestamp: Date.now() };
  },

  // ── Auth ─────────────────────────────────────────────────────────────
  // Explicit, native-friendly wrappers around the AuthBasic Block so the
  // Flutter client has a simple, stable contract to call.
  async register(username: string, password: string) {
    await auth.signUp(username, password);
    // No email confirmation configured, so sign in immediately.
    const user = await auth.signIn(username, password, context);
    return { username: user.username };
  },

  async login(username: string, password: string) {
    const user = await auth.signIn(username, password, context);
    return { username: user.username };
  },

  async logout() {
    await auth.signOut(context);
    return { success: true };
  },

  async me() {
    const user = await auth.getCurrentUser(context);
    return user ? { username: user.username } : null;
  },

  // ── Per-user history (requires login) ────────────────────────────────
  async saveEntry(
    mode: string,
    original: string,
    output: string,
    sourceLang: string,
    targetLang: string,
  ) {
    const user = await auth.requireAuth(context);
    const entry = {
      userId: user.username,
      entryId: Date.now().toString(36) + crypto.randomBytes(6).toString('hex'),
      mode,
      original,
      output,
      sourceLang,
      targetLang,
      createdAt: Date.now(),
    };
    await history.put(entry);
    return entry;
  },

  async listHistory() {
    const user = await auth.requireAuth(context);
    const out: Array<z.infer<typeof historySchema>> = [];
    for await (const e of history.query({
      index: 'byCreatedAt',
      where: { userId: { equals: user.username } },
    })) {
      out.push(e);
    }
    return out;
  },

  async clearHistory() {
    const user = await auth.requireAuth(context);
    let count = 0;
    const ids: string[] = [];
    for await (const e of history.query({
      where: { userId: { equals: user.username } },
    })) {
      ids.push(e.entryId);
    }
    for (const entryId of ids) {
      await history.delete({ userId: user.username, entryId });
      count++;
    }
    return { success: true, count };
  },
}));

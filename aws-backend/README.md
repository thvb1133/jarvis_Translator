# Kimchi Jarvis — AWS backend (AWS Blocks)

This is the **AWS backend** for Kimchi Jarvis, built with
[AWS Blocks](https://docs.aws.amazon.com/blocks/latest/devguide/what-is-blocks.html).
It adds **user accounts / login** and **per‑user saved history** to the app.

What it provisions on AWS (via one deploy):

| Feature | AWS Block | AWS service |
| --- | --- | --- |
| Login / signup / sessions | `AuthBasic` | Amazon DynamoDB + JWT |
| Per‑user saved history | `DistributedTable` | Amazon DynamoDB |
| The API itself (JSON‑RPC) | `ApiNamespace` | Amazon API Gateway + AWS Lambda |

> Upgrade path: swap `AuthBasic` for `AuthCognito` in `aws-blocks/index.ts`
> (same interface) to get managed Amazon Cognito with MFA, groups, and social
> sign‑in.

The Flutter app talks to this backend over HTTP JSON‑RPC 2.0 at
`POST <api-url>/aws-blocks/api`.

---

## API methods

| Method | Params | Auth | Purpose |
| --- | --- | --- | --- |
| `ping` | – | public | Health check |
| `register` | `username, password` | public | Create account + start session |
| `login` | `username, password` | public | Start session |
| `logout` | – | session | End session |
| `me` | – | session | Current user or `null` |
| `saveEntry` | `mode, original, output, sourceLang, targetLang` | required | Save a history entry |
| `listHistory` | – | required | List the user's saved entries |
| `clearHistory` | – | required | Delete the user's saved entries |

Example (local):

```bash
curl -X POST http://localhost:3001/aws-blocks/api \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"api.ping","params":[],"id":1}'
```

---

## 1. Run it locally (no AWS account needed)

```bash
cd aws-backend
npm install
npm run dev      # http://localhost:3001  (Blocks use in-memory mocks)
```

Everything works locally with mock storage — great for developing and demoing
the flow before you touch AWS.

## 2. Deploy to AWS (for the hackathon)

**Prerequisites (one time):**

1. **Node.js 22+** — https://nodejs.org/
2. **An AWS account** — https://portal.aws.amazon.com/billing/signup
3. **AWS CLI v2**, configured with credentials — run `aws sts get-caller-identity` to verify.
4. **Bootstrap CDK** for your account/region (one time):
   ```bash
   npx cdk bootstrap aws://<ACCOUNT_ID>/<REGION>
   ```

**Deploy:**

```bash
cd aws-backend
npm install

# Fast, ephemeral test environment on real AWS:
npm run sandbox

# …or a full/persistent deployment:
npm run deploy
```

The deploy prints your **API Gateway URL**. Your JSON‑RPC endpoint is that URL
+ `/aws-blocks/api`.

To tear everything down:

```bash
npm run sandbox:destroy   # or: npm run destroy
```

## 3. Let the deployed site (Vercel) use it — CORS

The Flutter web app is hosted on Vercel (a different domain), so allow that
origin on the backend Lambda. In `aws-blocks/index.cdk.ts` add your Vercel
domain to `CORS_ALLOWED_ORIGINS` (each entry is a regex):

```ts
blocksStack.handler.addEnvironment(
  'CORS_ALLOWED_ORIGINS',
  'https://kimchi-jarvis-translator\\.vercel\\.app',
);
```

The session cookie is already configured for cross‑domain use
(`crossDomain: true` in `index.ts`).

## 4. Point the Flutter app at it

Build/run the Flutter app with the API base URL:

```bash
flutter run --dart-define=KIMCHI_API_URL=https://<your-api>/aws-blocks/api
```

When `KIMCHI_API_URL` is empty (the default), the app runs exactly as before
with no login — so this backend is fully optional until you deploy it.

---

## Notes

- `AuthBasic` here uses no email confirmation, so signup is instant
  (username + password, min 8 chars). Add a `codeDelivery` callback in
  `index.ts` to require email verification.
- All state is per‑user: history is keyed by the signed‑in username.

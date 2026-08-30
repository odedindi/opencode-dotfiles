# Security Auditor

Security review guidance for **Oded's stack**: TypeScript, Express, React, Prisma, PostgreSQL. Based on OWASP Top 10.

**Stance**: Security is non-negotiable. Flag issues even when not explicitly asked. Never suggest "it's probably fine."

---

## 0. Audit Trigger

When reviewing or writing code, apply this skill automatically for:
- Authentication / authorization logic
- Any code handling user input
- Database queries
- File uploads or filesystem access
- External API calls
- Environment config and secrets
- Any new dependency added

---

## 1. OWASP Top 10 — Applied to This Stack

### A01: Broken Access Control
**Most common. Most critical.**

```typescript
// ❌ VULNERABLE: user can access any resource by ID
app.get('/posts/:id', async (req, res) => {
  const post = await prisma.post.findUnique({ where: { id: req.params.id } });
  res.json(post);
});

// ✅ SECURE: always scope to the authenticated user
app.get('/posts/:id', requireAuth, async (req, res) => {
  const post = await prisma.post.findUnique({
    where: { id: req.params.id, userId: req.user.id }, // ownership check
  });
  if (!post) return res.status(404).json({ error: { code: 'NOT_FOUND' } });
  res.json(post);
});
```

Always ask: **"Can user A access user B's data by changing the ID?"**

### A02: Cryptographic Failures
- Never store passwords in plaintext or with reversible encryption — use `bcrypt` (cost ≥ 12) or `argon2`
- Never log passwords, tokens, or PII
- Use `crypto.randomBytes(32)` for tokens, never `Math.random()`
- Tokens in httpOnly cookies > localStorage (XSS-safe)
- HTTPS in production — enforce via HSTS header

```typescript
import { hash, compare } from 'bcrypt';
const BCRYPT_ROUNDS = 12;
const hashed = await hash(password, BCRYPT_ROUNDS);
const valid = await compare(password, hashed);
```

### A03: Injection

**SQL Injection via Prisma**: Prisma parameterizes by default. Risk only arises with `$queryRaw` / `$executeRaw`:

```typescript
// ❌ VULNERABLE
await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE email = '${email}'`);

// ✅ SAFE — Prisma's tagged template literal parameterizes automatically
await prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;
```

**NoSQL Injection (MongoDB)**: Never pass unsanitized user input as a MongoDB query object.

**Command Injection**: Never pass user input to `exec()`, `spawn()` with shell: true, or similar.

### A04: Insecure Design
- Enforce rate limiting on auth endpoints (login, signup, password reset)
- Implement account lockout or exponential backoff after failed logins
- Don't expose stack traces or internal error messages to clients
- Verify email ownership before granting access

### A05: Security Misconfiguration
```typescript
// Required Express security headers (use helmet)
import helmet from 'helmet';
app.use(helmet());

// Never in production:
app.use(cors({ origin: '*' })); // ❌ — specify allowed origins
app.use(express.json({ limit: '50mb' })); // ❌ — set sensible limit (e.g., '1mb')
```

- Remove default credentials, example accounts, debug endpoints before shipping
- Set `NODE_ENV=production` — some frameworks expose debug info in dev mode

### A06: Vulnerable and Outdated Components
```bash
npm audit                    # check for known vulnerabilities
npm audit --audit-level=high # fail CI on high/critical
```
- Run `npm audit` in CI
- Keep dependencies updated (use Dependabot or Renovate)
- Check license compatibility for production dependencies

### A07: Identification and Authentication Failures
- JWT: use RS256 (asymmetric) for distributed systems, HS256 acceptable for single-service
- Short access token TTL (15 min), longer refresh token (7–30 days) with rotation
- Invalidate all sessions on password change
- Never put sensitive data in JWT payload (it's base64, not encrypted)

```typescript
// JWT verification — always verify, never just decode
import { verify } from 'jsonwebtoken';
try {
  const payload = verify(token, process.env.JWT_SECRET!); // throws on invalid
} catch {
  return res.status(401).json({ error: { code: 'UNAUTHORIZED' } });
}
```

### A08: Software and Data Integrity Failures
- Pin dependency versions in production (`package-lock.json` committed)
- Validate webhook payloads with HMAC signatures before processing
- Don't `eval()` user-supplied strings

```typescript
// Webhook signature verification (e.g., Stripe)
import { createHmac, timingSafeEqual } from 'crypto';
function verifyWebhookSignature(payload: Buffer, signature: string, secret: string): boolean {
  const expected = createHmac('sha256', secret).update(payload).digest('hex');
  return timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}
```

### A09: Security Logging and Monitoring Failures
Log these events (to a structured log, not console.log):
- Failed authentication attempts (with IP, user agent — never password)
- Successful logins with suspicious patterns
- Authorization failures (403s)
- Admin actions
- Unexpected errors

Do NOT log: passwords, tokens, full PII, credit card numbers.

### A10: Server-Side Request Forgery (SSRF)
If your app fetches URLs provided by users:
- Allowlist allowed domains
- Block requests to `localhost`, `127.0.0.1`, `169.254.x.x` (cloud metadata)
- Use a dedicated HTTP client with SSRF protections

---

## 2. Secrets Management

### Hard rules
- **Never** commit secrets to Git — not even to `.env` files in the repo
- `.env` in `.gitignore` — always check before committing
- Use `process.env.X` only via a validated config module (with Zod)
- Rotate secrets if they're ever accidentally committed (even briefly)

```typescript
// config/env.ts — validate env at startup, fail fast if missing
import { z } from 'zod';

const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  NODE_ENV: z.enum(['development', 'test', 'production']),
});

export const env = EnvSchema.parse(process.env); // throws on startup if invalid
```

### Secret detection in diffs
Automatically flag if any of these appear in a diff being reviewed:
- Strings matching `sk_live_`, `pk_live_`, `ghp_`, `AKIA`, `-----BEGIN`
- Variables named `SECRET`, `PASSWORD`, `API_KEY`, `TOKEN` with hardcoded values
- `.env` files being committed
- `console.log(password)` or similar

---

## 3. Input Validation

- All external input (req.body, req.query, req.params) validated with Zod before use
- File uploads: validate MIME type server-side (not just extension), set max size, scan for malware if sensitive
- Never `JSON.parse()` user input without try/catch and schema validation

---

## 4. Frontend Security (React)

- Never store tokens in `localStorage` — use httpOnly cookies
- Avoid `dangerouslySetInnerHTML` with any user-supplied content
- Sanitize HTML if you must render it (use DOMPurify)
- Use `rel="noopener noreferrer"` on all `target="_blank"` links
- CSP headers via helmet's `contentSecurityPolicy`

---

## 5. Security Checklist for New Endpoints

Before shipping any new route:
- [ ] Authentication required? (is `requireAuth` middleware applied?)
- [ ] Authorization checked? (does the user own this resource?)
- [ ] Input validated with Zod?
- [ ] Rate limiting applied? (especially for auth/mutation routes)
- [ ] Errors return generic messages (no stack traces to client)?
- [ ] Sensitive data excluded from response?
- [ ] Logs added for sensitive actions?

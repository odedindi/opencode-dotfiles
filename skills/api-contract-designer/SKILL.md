# API Contract Designer

Consistent, predictable REST API design for **Oded's stack**: Express + TypeScript + Zod + Prisma.

---

## 0. Principle

An API is a contract. Consistency is more important than perfection. Make it unsurprising.

---

## 1. URL Design

### Resource naming
- **Plural nouns** for collections: `/users`, `/posts`, `/invoices`
- **Kebab-case** for multi-word: `/billing-accounts`, `/api-keys`
- **Nested** only for true ownership: `/users/:userId/posts` (a post belongs to a user)
- **Flat** when the child can exist independently: `/posts/:postId` (don't nest `/users/:id/posts/:postId`)
- **Actions** as sub-resources when verbs are needed: `POST /invoices/:id/send`, `POST /users/:id/verify-email`

```
GET    /users              → list users
POST   /users              → create user
GET    /users/:id          → get user
PATCH  /users/:id          → partial update
PUT    /users/:id          → full replacement (rare — prefer PATCH)
DELETE /users/:id          → delete user
POST   /users/:id/suspend  → action that doesn't fit CRUD
```

### Versioning
- Prefix all routes: `/api/v1/users`
- Version in URL, not header (easier to test, debug, link)
- Never break v1 — add v2 for breaking changes

---

## 2. Request Design

### Input validation: always Zod
```typescript
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(['admin', 'member']).default('member'),
});

// In route handler:
const result = CreateUserSchema.safeParse(req.body);
if (!result.success) {
  return res.status(400).json(formatZodError(result.error));
}
```

### Query parameters
- Filtering: `?status=active&role=admin`
- Sorting: `?sort=createdAt&order=desc` (never `?orderBy=createdAt_desc`)
- Pagination: `?cursor=xxx&limit=20` (cursor-based) or `?page=1&limit=20` (offset — acceptable for small datasets)
- Search: `?q=search+term`
- Field selection: `?fields=id,name,email` (only if payload size is a real concern)

---

## 3. Response Design

### Success responses

| Operation | Status | Body |
|---|---|---|
| GET (single) | 200 | The resource object |
| GET (list) | 200 | `{ data: [...], meta: { total, cursor } }` |
| POST (create) | 201 | The created resource |
| PATCH/PUT | 200 | The updated resource |
| DELETE | 204 | Empty body |
| POST (action) | 200 | Result of the action |

### List response shape (always)
```json
{
  "data": [...],
  "meta": {
    "total": 142,
    "limit": 20,
    "cursor": "eyJpZCI6IjUwIn0="
  }
}
```

### Single resource shape
```json
{
  "id": "usr_01H...",
  "email": "user@example.com",
  "name": "Jane Doe",
  "createdAt": "2024-01-15T10:00:00.000Z"
}
```

**No envelope for single resources** (`{ data: {...} }` is unnecessary noise for GET /users/:id).

---

## 4. Error Responses

### Standard error shape
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      { "field": "email", "message": "Invalid email address" }
    ]
  }
}
```

### Status code guide

| Situation | Status | Code |
|---|---|---|
| Invalid input / schema violation | 400 | `VALIDATION_ERROR` |
| Missing or invalid auth token | 401 | `UNAUTHORIZED` |
| Valid token, insufficient permission | 403 | `FORBIDDEN` |
| Resource not found | 404 | `NOT_FOUND` |
| Conflict (duplicate, stale update) | 409 | `CONFLICT` |
| Rate limit exceeded | 429 | `RATE_LIMIT_EXCEEDED` |
| Internal server error | 500 | `INTERNAL_ERROR` |

### Rule: Never return 200 with an error body. Never return 500 for client mistakes.

---

## 5. Field Conventions

| Convention | Rule |
|---|---|
| **Case** | `camelCase` for all JSON fields |
| **IDs** | Prefixed strings: `usr_xxx`, `inv_xxx`, `pst_xxx` (not raw UUIDs exposed directly) |
| **Timestamps** | ISO 8601 UTC: `"2024-01-15T10:00:00.000Z"` |
| **Booleans** | `isActive`, `hasAccess` — never `active`, `access` |
| **Nulls** | Omit optional missing fields rather than returning `null` (preference) |
| **Pagination cursors** | Opaque base64 strings — never expose raw DB IDs as cursors |

---

## 6. Pagination

### Cursor-based (default for production)
```typescript
// Request: GET /posts?cursor=eyJpZCI6IjUwIn0=&limit=20
// Response:
{
  "data": [...],
  "meta": {
    "limit": 20,
    "nextCursor": "eyJpZCI6IjcwIn0=",  // null if no more pages
    "hasMore": true
  }
}

// Implementation (Prisma)
const posts = await prisma.post.findMany({
  take: limit + 1,
  cursor: cursor ? { id: decodeCursor(cursor) } : undefined,
  orderBy: { createdAt: 'desc' },
});
const hasMore = posts.length > limit;
const data = hasMore ? posts.slice(0, -1) : posts;
```

### Offset-based (acceptable for small, non-live datasets)
```
GET /reports?page=2&limit=20
→ { data: [...], meta: { total: 142, page: 2, limit: 20, totalPages: 8 } }
```

---

## 7. Auth Patterns

- Auth via `Authorization: Bearer <token>` header — never in query string
- Return `401` for missing/expired/invalid tokens
- Return `403` for valid token with insufficient permission
- Never expose which users exist via auth errors (return same message for "wrong password" and "user not found" on login)

---

## 8. Common Anti-Patterns to Flag

- Verbs in resource URLs: `/getUsers`, `/createPost` — use HTTP methods
- Inconsistent pluralization: `/user` and `/posts` in the same API
- Returning `200` with `{ success: false, error: "..." }` — use proper status codes
- Exposing internal DB IDs directly as the public identifier
- Returning the full object on `DELETE` — return 204 with no body
- Inconsistent timestamp formats across endpoints
- Different error shapes across endpoints
- No pagination on list endpoints that could grow
- Accepting both `camelCase` and `snake_case` — pick one

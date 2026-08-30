# Database Query Optimizer

This skill covers database optimization for **Oded's stack**: PostgreSQL (primary), SQLite, MongoDB, with Prisma as ORM.

---

## PostgreSQL — Core Optimization

### EXPLAIN ANALYZE — Read This First

```sql
-- Always use EXPLAIN ANALYZE to diagnose slow queries
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) 
SELECT * FROM users WHERE email = 'test@example.com';

-- Key things to look for:
-- Seq Scan → bad on large tables (needs index)
-- Index Scan → good
-- Nested Loop → fine for small datasets, bad for large
-- Hash Join → good for large dataset joins
-- actual time=X → actual execution time in ms
-- rows=X (rows=Y) → estimated vs actual row count (huge mismatch = stale stats)
-- Buffers: hit=X read=Y → cache hits vs disk reads
```

### Essential Index Patterns

```sql
-- Single column index (most common)
CREATE INDEX idx_users_email ON users(email);

-- Composite index: order matters!
-- Rule: most selective + most filtered columns first
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
-- Supports: WHERE user_id = ? AND status = ?
-- Supports: WHERE user_id = ?
-- Does NOT support alone: WHERE status = ?

-- Partial index: index only rows matching a condition (smaller, faster)
CREATE INDEX idx_orders_pending ON orders(created_at) WHERE status = 'pending';

-- Index for LIKE queries (prefix search only)
CREATE INDEX idx_users_name_prefix ON users(name text_pattern_ops);
-- Supports: WHERE name LIKE 'Jo%'
-- Does NOT support: WHERE name LIKE '%ohn'

-- JSON index
CREATE INDEX idx_metadata_type ON events((metadata->>'type'));

-- Covering index (includes extra columns to avoid table lookup)
CREATE INDEX idx_orders_user_covering ON orders(user_id) INCLUDE (total, created_at);

-- NEVER create indexes on low-cardinality columns alone (e.g., boolean, status with 2 values)
-- They're often ignored by the query planner
```

### Common Slow Query Patterns

```sql
-- BAD: Function on indexed column (index not used)
WHERE LOWER(email) = 'test@example.com'
-- FIX: Use functional index
CREATE INDEX idx_users_email_lower ON users(LOWER(email));

-- BAD: Leading wildcard (full text search needed)
WHERE name LIKE '%john%'
-- FIX: Full text search
WHERE to_tsvector('english', name) @@ to_tsquery('john')
-- Or use pg_trgm extension for arbitrary LIKE
CREATE INDEX idx_name_trgm ON users USING gin(name gin_trgm_ops);

-- BAD: Implicit type cast prevents index use
WHERE user_id = '123'  -- user_id is integer, '123' is text
-- FIX: match types
WHERE user_id = 123

-- BAD: OR on different indexed columns (may cause full scan)
WHERE email = ? OR phone = ?
-- FIX: Union
SELECT * FROM users WHERE email = ?
UNION ALL
SELECT * FROM users WHERE phone = ?

-- BAD: NOT IN with NULL values (always false when subquery has NULLs)
WHERE id NOT IN (SELECT user_id FROM banned_users)
-- FIX: NOT EXISTS
WHERE NOT EXISTS (SELECT 1 FROM banned_users WHERE user_id = users.id)
```

### Pagination — Do It Right

```sql
-- BAD: OFFSET gets slower as offset grows (has to scan all rows)
SELECT * FROM posts ORDER BY created_at DESC LIMIT 20 OFFSET 10000;

-- GOOD: Cursor-based pagination
SELECT * FROM posts 
WHERE created_at < '2024-01-15T10:30:00Z'  -- cursor from previous page
ORDER BY created_at DESC 
LIMIT 20;

-- For unique cursor, use a unique column (id) as tiebreaker
SELECT * FROM posts
WHERE (created_at, id) < ('2024-01-15', 'uuid-here')
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

---

## Prisma — Common Performance Issues

### N+1 Detection and Fix

```typescript
// BAD: N+1 — one query per user to get their posts
const users = await prisma.user.findMany()
for (const user of users) {
  const posts = await prisma.post.findMany({ where: { userId: user.id } })  // N queries!
}

// GOOD: Include (single JOIN query)
const users = await prisma.user.findMany({
  include: {
    posts: true
  }
})

// BETTER: Select only what you need
const users = await prisma.user.findMany({
  select: {
    id: true,
    name: true,
    posts: {
      select: { id: true, title: true },
      take: 5,
      orderBy: { createdAt: 'desc' }
    }
  }
})
```

### `include` vs `select`

```typescript
// include: adds fields ON TOP of all scalar fields
prisma.user.findMany({ include: { posts: true } })
// Returns: all user columns + posts

// select: returns ONLY what you specify
prisma.user.findMany({ 
  select: { id: true, name: true, posts: { select: { title: true } } } 
})
// Returns: only id, name, post titles — much leaner

// RULE: Use select on hot paths, include is fine for admin/low-traffic routes
```

### Aggregations

```typescript
// BAD: Load all records then count in JS
const users = await prisma.user.findMany()
const count = users.length  // loaded all rows for a count!

// GOOD: Database does the counting
const count = await prisma.user.count({ where: { active: true } })

// groupBy: for analytics queries
const postsByUser = await prisma.post.groupBy({
  by: ['userId'],
  _count: { id: true },
  _sum: { views: true },
  orderBy: { _count: { id: 'desc' } },
  take: 10
})
```

### Prisma Raw Queries — When to Use

```typescript
// Use for: complex JUINs, window functions, CTEs, database-specific features
// Use sparingly: loses type safety (use Zod to validate output)

const results = await prisma.$queryRaw<Array<{id: string; total: number}>>`
  SELECT 
    u.id,
    COALESCE(SUM(o.total), 0) as total
  FROM users u
  LEFT JOIN orders o ON o.user_id = u.id
  WHERE u.created_at > ${startDate}
  GROUP BY u.id
  HAVING SUM(o.total) > 1000
  ORDER BY total DESC
  LIMIT 50
`
// Always validate results with Zod if using $queryRaw
const validated = z.array(z.object({ id: z.string(), total: z.number() })).parse(results)
```

### Connection Pool

```typescript
// In production: configure connection pool
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL
    }
  },
  // pgBouncer in transaction mode requires no_prepare
})

// DATABASE_URL pool parameters
// postgresql://user:pass@host:port/db?connection_limit=10&pool_timeout=10
```

---

## Migration Safety (Zero-Downtime)

```sql
-- SAFE additions (non-blocking)
ALTER TABLE users ADD COLUMN metadata jsonb;  -- OK if nullable or has default
ALTER TABLE users ADD COLUMN active boolean DEFAULT true;  -- OK

-- DANGEROUS on large tables (lock entire table)
ALTER TABLE users ADD COLUMN profile_id uuid NOT NULL;  -- BLOCKS reads/writes
ALTER TABLE users ALTER COLUMN name TYPE varchar(500);  -- BLOCKS

-- SAFE pattern for NOT NULL columns:
-- Step 1 (deploy): Add nullable column
ALTER TABLE users ADD COLUMN tier varchar(50);
-- Step 2 (backfill, in batches): 
UPDATE users SET tier = 'free' WHERE tier IS NULL AND id > ? LIMIT 1000;
-- Step 3 (after full backfill): Add constraint
ALTER TABLE users ALTER COLUMN tier SET NOT NULL;

-- Index creation (lock-free)
CREATE INDEX CONCURRENTLY idx_users_tier ON users(tier);  -- non-blocking
-- Regular CREATE INDEX locks the table!
```

---

## MongoDB — Aggregation & Index Patterns

### Indexes

```javascript
// Single field
db.users.createIndex({ email: 1 })  // ascending
db.users.createIndex({ createdAt: -1 })  // descending (for sort)

// Compound index (same rules: order matters, leftmost prefix)
db.orders.createIndex({ userId: 1, status: 1, createdAt: -1 })

// Partial index
db.orders.createIndex(
  { createdAt: 1 }, 
  { partialFilterExpression: { status: 'pending' } }
)

// Text search
db.posts.createIndex({ content: 'text', title: 'text' })
db.posts.find({ $text: { $search: 'mongodb performance' } })
```

### Aggregation Pipeline — Optimization Rules

```javascript
// RULE 1: $match early — filter before any $lookup or $unwind
db.orders.aggregate([
  { $match: { status: 'completed', userId: ObjectId(id) } },  // FIRST
  { $lookup: { ... } },
  { $group: { ... } }
])

// RULE 2: $project early — reduce document size before expensive ops
{ $project: { _id: 1, total: 1, userId: 1 } }  // drop fields ASAP

// RULE 3: Avoid $unwind on large arrays (can explode document count)
// Use $filter or $slice instead when possible

// RULE 4: $lookup with pipeline is more efficient for filtered joins
{ $lookup: {
  from: 'products',
  let: { productId: '$productId' },
  pipeline: [
    { $match: { $expr: { $eq: ['$_id', '$$productId'] } } },
    { $project: { name: 1, price: 1 } }  // project inside pipeline
  ],
  as: 'product'
}}
```

### Explain in MongoDB

```javascript
db.users.find({ email: 'test@example.com' }).explain('executionStats')
// Look for: 
// IXSCAN → index used (good)
// COLLSCAN → full collection scan (bad for large collections)
// executionTimeMillis → actual time
// totalDocsExamined vs nReturned → should be close to 1:1
```

---

## SQLite — Specific Considerations

```sql
-- SQLite pragma for performance
PRAGMA journal_mode = WAL;  -- Write-Ahead Logging (better concurrency)
PRAGMA synchronous = NORMAL;  -- Safer than FULL, faster
PRAGMA cache_size = 10000;  -- 10MB page cache
PRAGMA foreign_keys = ON;   -- Always enable

-- SQLite doesn't support concurrent writes — use WAL mode
-- For read-heavy workloads: read replicas or connection pooling (read-only connections)
-- For write-heavy: consider moving to PostgreSQL

-- Covering indexes work the same as PostgreSQL
-- No EXPLAIN ANALYZE, use: EXPLAIN QUERY PLAN
EXPLAIN QUERY PLAN SELECT * FROM users WHERE email = 'test@example.com';
```

---

## Query Diagnosis Checklist

When a query is slow, check in this order:

1. **Run EXPLAIN ANALYZE** — is it doing a Seq Scan on a large table?
2. **Check indexes** — does an index exist for the WHERE/ORDER BY columns?
3. **Check index usage** — is the query pattern using the index's leftmost prefix?
4. **Check N+1** — is this running inside a loop?
5. **Check row count** — are you fetching more than you need? Add LIMIT.
6. **Check column selection** — are you SELECT * when you need 3 columns?
7. **Check join cardinality** — does the JOIN explode the result set?
8. **Check statistics freshness** — run `ANALYZE table_name` if estimates are way off

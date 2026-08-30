# TypeScript Fullstack Engineer

You are writing code for **Oded**, a fullstack TypeScript engineer. Match his exact style and preferences.

---

## Stack Profile

**Primary**: TypeScript (strict mode always), React (frontend), Express (backend), Prisma (ORM), Zod (validation)
**Exploring**: Effect-ts (functional effects system)
**Secondary**: Python, PHP, Go, Rust (learning)
**Databases**: PostgreSQL (primary), SQLite, MongoDB

---

## TypeScript Standards

### Type Safety — Non-Negotiable

```typescript
// NEVER use these
as any
@ts-ignore
@ts-expect-error
// NEVER suppress type errors — fix the root cause

// PREFER branded types for domain values
type UserId = string & { readonly __brand: 'UserId' }
type Email = string & { readonly __brand: 'Email' }

// PREFER discriminated unions over boolean flags
type Result<T> =
  | { success: true; data: T }
  | { success: false; error: string }

// PREFER unknown over any for external data
function parseInput(data: unknown): ParsedData {
  // validate with Zod, then use
}
```

### Generics — Write them properly

```typescript
// PREFER: explicit, constrained generics
function pick<T extends object, K extends keyof T>(obj: T, keys: K[]): Pick<T, K>

// AVOID: overly generic with no constraints
function doThing<T>(x: T): T  // OK only when truly generic
```

### Error Handling

```typescript
// PREFER: explicit error returns over throw (unless library boundary)
type AppError = 
  | { type: 'not_found'; id: string }
  | { type: 'unauthorized' }
  | { type: 'validation'; errors: ZodError }

// In Express handlers: always catch async errors
router.get('/user/:id', async (req, res, next) => {
  try {
    const user = await userService.findById(req.params.id)
    res.json(user)
  } catch (err) {
    next(err)  // pass to error middleware
  }
})

// NEVER: empty catch blocks
catch (err) {}  // FORBIDDEN
```

---

## Zod — Validation Standard

```typescript
// Define schemas first, infer types from them
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(['admin', 'user', 'guest']),
  createdAt: z.date(),
})
type User = z.infer<typeof UserSchema>

// Use .strict() on input schemas to reject unknown keys
const CreateUserInput = z.object({
  email: z.string().email(),
  name: z.string().min(1),
}).strict()

// Parse at the boundary (API input, env vars, external data)
// After parse, trust the type — don't re-validate internally
```

---

## React Patterns

### Component Structure

```typescript
// Function components only (no class components)
// Props interface above component
interface ButtonProps {
  label: string
  onClick: () => void
  variant?: 'primary' | 'secondary' | 'ghost'
  disabled?: boolean
}

export function Button({ label, onClick, variant = 'primary', disabled = false }: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant }), disabled && 'opacity-50')}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  )
}
```

### Hooks

```typescript
// Custom hooks: extract complex stateful logic
// Name: useXxx
// Return: named object (not array, unless always destructured in order)
function useUserProfile(userId: string) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchUser(userId).then(data => {
      if (!cancelled) { setUser(data); setLoading(false) }
    }).catch(err => {
      if (!cancelled) { setError(err); setLoading(false) }
    })
    return () => { cancelled = true }
  }, [userId])

  return { user, loading, error }
}

// Dependency arrays: always complete — exhaustive-deps must be satisfied
// If you need to suppress, use useCallback/useMemo to stabilize references first
```

### State Management

```typescript
// LOCAL state: useState / useReducer
// SHARED state: Context + useReducer (avoid prop drilling beyond 2 levels)
// SERVER state: React Query / SWR (not useState + useEffect for API calls)
// FORMS: react-hook-form with Zod resolver
```

### Performance

```typescript
// useMemo: only for expensive computations (not every derived value)
// useCallback: for callbacks passed to memoized children
// React.memo: for pure components that receive the same props frequently
// AVOID: premature optimization — profile first

// Key rule: keys should be stable IDs, never array index for dynamic lists
```

---

## Express Patterns

### Middleware Structure

```typescript
// Route file structure: router -> middleware -> handler
import { Router } from 'express'
import { z } from 'zod'
import { authenticate } from '../middleware/auth'
import { validate } from '../middleware/validate'

const router = Router()

const CreatePostSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1),
  tags: z.array(z.string()).optional(),
})

router.post(
  '/posts',
  authenticate,  // auth first
  validate(CreatePostSchema),  // then validate
  async (req, res, next) => {
    try {
      const post = await postService.create(req.user.id, req.body)
      res.status(201).json(post)
    } catch (err) {
      next(err)
    }
  }
)
```

### Validation Middleware

```typescript
// Generic validation middleware using Zod
function validate<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body)
    if (!result.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: result.error.flatten(),
      })
    }
    req.body = result.data  // parsed + typed
    next()
  }
}
```

### Error Middleware

```typescript
// Global error handler — always last middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ error: err.message })
  }
  console.error(err)
  res.status(500).json({ error: 'Internal server error' })
})
```

### Service Layer

```typescript
// Keep routes thin — business logic lives in services
// Services: pure functions or classes, testable in isolation
// Services never import Express types (Request, Response)
class UserService {
  constructor(private db: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    return this.db.user.findUnique({ where: { id } })
  }

  async create(input: CreateUserInput): Promise<User> {
    // validation already done at route level via Zod
    return this.db.user.create({ data: input })
  }
}
```

---

## Prisma Patterns

### Queries

```typescript
// PREFER: explicit select over selecting everything
const user = await prisma.user.findUnique({
  where: { id },
  select: {
    id: true,
    email: true,
    name: true,
    // DO NOT select: password, sensitiveField
  }
})

// PREFER: findUniqueOrThrow / findFirstOrThrow when null is unexpected
const user = await prisma.user.findUniqueOrThrow({ where: { id } })

// N+1 prevention: use include or nested select, not per-record queries
const usersWithPosts = await prisma.user.findMany({
  include: {
    posts: {
      select: { id: true, title: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      take: 5,  // always paginate nested relations
    }
  }
})
```

### Transactions

```typescript
// Use $transaction for multi-step operations that must be atomic
const [user, profile] = await prisma.$transaction([
  prisma.user.create({ data: userData }),
  prisma.profile.create({ data: profileData }),
])

// Interactive transactions for complex logic
const result = await prisma.$transaction(async (tx) => {
  const order = await tx.order.create({ data: orderData })
  await tx.inventory.update({
    where: { productId: order.productId },
    data: { quantity: { decrement: order.quantity } }
  })
  return order
})
```

### Migrations

```typescript
// ALWAYS: add indexes for columns used in WHERE/ORDER BY/JOIN conditions
// ALWAYS: nullable columns should have a migration default for existing rows
// NEVER: drop columns in the same migration as code changes (deploy code first)
// PREFER: additive migrations (add columns, rename via shadow column + backfill)
```

---

## Code Quality Rules

### Naming

```typescript
// Interfaces/Types: PascalCase (no "I" prefix)
interface UserRepository {}  // NOT IUserRepository

// Functions/variables: camelCase
const fetchUserData = async () => {}

// Constants: SCREAMING_SNAKE_CASE only for true compile-time constants
const MAX_RETRY_ATTEMPTS = 3

// Enums: PascalCase key and value
enum UserRole { Admin = 'admin', User = 'user' }
// PREFER const union types over enums for simple string values
type UserRole = 'admin' | 'user' | 'guest'
```

### File Organization

```
src/
├── routes/         # Express route handlers (thin)
├── services/       # Business logic (no Express deps)
├── middleware/     # Express middleware
├── lib/            # Utilities, shared helpers
├── types/          # Shared TypeScript types/interfaces
├── db/             # Prisma client, DB utilities
└── config/         # Config parsing (Zod-validated env vars)
```

### Imports

```typescript
// PREFER: named imports over default imports for internal modules
import { UserService } from './services/user'
// AVOID: circular imports — if you have them, extract to a shared module
```

### Anti-Patterns to Flag

```typescript
// NEVER: mutate function parameters
function updateUser(user: User) {
  user.name = 'new name'  // NO — return new object
}

// NEVER: boolean parameters that change function behavior
function process(data: Data, isAdmin: boolean) {}  // split into two functions

// NEVER: comments explaining what the code does
// x++ // increment x by 1
// DO: comments explaining WHY (non-obvious decisions, trade-offs)

// NEVER: dead code left commented out
// const oldImplementation = ...

// AVOID: deeply nested callbacks or conditionals (>3 levels)
// Prefer: early returns, extracted functions
```

---

## When Helping

1. **Match existing patterns** — before suggesting a pattern, check what already exists
2. **Be explicit about types** — never let inference do the heavy lifting at API boundaries
3. **Validate at boundaries** — Zod at HTTP layer, trust types internally
4. **Think about N+1** — flag any loop-with-query pattern
5. **Flag security issues** — SQL injection, auth bypass, mass assignment, exposed secrets
6. **Suggest Effect-ts when appropriate** — for complex async orchestration or when Oded is exploring it

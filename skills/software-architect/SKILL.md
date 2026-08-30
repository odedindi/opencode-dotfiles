# Software Architect

Architecture guidance for **Oded's stack**: TypeScript, Express (backend), React (frontend), Prisma, PostgreSQL/SQLite/MongoDB.

---

## 0. First Principle

Architecture exists to make change cheap. Every structural decision should be evaluated against: **"How hard will it be to change this in 6 months?"**

---

## 1. Backend Architecture (Express / TypeScript)

### Two Valid Approaches — Choose Per Project

**Layered** (horizontal) — good for small/medium CRUD-heavy apps:
```
src/
  routes/       # HTTP layer only — parse req, call service, return res
  services/     # Business logic — pure TS, no HTTP, no DB
  repositories/ # Data access — Prisma queries live here
  types/        # Shared interfaces and Zod schemas
  middleware/   # Auth, error handling, logging
```

**Feature-sliced** (vertical) — good for larger apps with clear domain boundaries:
```
src/
  features/
    users/
      users.router.ts
      users.service.ts
      users.repo.ts
      users.schema.ts   # Zod
      users.types.ts
  shared/
    middleware/
    db/
    errors/
```

**Default recommendation**: Start layered, migrate to feature-sliced when a single layer file exceeds ~300 lines or when two features' concerns start bleeding into each other.

### Layer Responsibilities (Hard Boundaries)

| Layer | Allowed | Forbidden |
|---|---|---|
| Route handler | Parse req, validate input (Zod), call service, return res | Business logic, DB access |
| Service | Business logic, orchestration | `req`/`res` objects, direct Prisma calls |
| Repository | Prisma queries, raw SQL | Business logic, HTTP concerns |
| Middleware | Cross-cutting concerns (auth, logging, rate limit) | Business logic |

### Service Design
- **Use factory functions, not classes.** Classes add ceremony without benefit in TypeScript functional style.
```typescript
// PREFERRED
export function createUserService(repo: UserRepository) {
  return {
    async getUser(id: string) { ... },
    async createUser(input: CreateUserInput) { ... },
  };
}

// AVOID (unnecessary for stateless services)
export class UserService {
  constructor(private repo: UserRepository) {}
}
```

- Services are pure business logic — they receive typed input, return typed output, throw typed errors.
- No `express.Request` inside a service. Ever.

### Error Handling Architecture
- Define a base `AppError` class with `statusCode` and `code`.
- Services throw `AppError` subclasses (e.g., `NotFoundError`, `ValidationError`, `ForbiddenError`).
- A single error-handling middleware at the Express root converts `AppError` → JSON response.
- Never swallow errors with empty catch blocks.

```typescript
export class AppError extends Error {
  constructor(
    public readonly message: string,
    public readonly statusCode: number,
    public readonly code: string
  ) { super(message); }
}

export class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}
```

### Dependency Injection Without a Framework
- Pass dependencies (repos, external clients) as arguments to factory functions.
- Compose at the app entrypoint (`app.ts` or `server.ts`).
- Avoid global singletons for testability.

```typescript
// server.ts
const userRepo = createUserRepository(prisma);
const userService = createUserService(userRepo);
const userRouter = createUserRouter(userService);
app.use('/users', userRouter);
```

---

## 2. Frontend Architecture (React / TypeScript)

### Component Hierarchy
```
src/
  components/      # Pure UI — no data fetching, no business logic
    ui/            # Design system primitives (Button, Input, Modal)
    [Feature]/     # Feature-specific components
  pages/           # Route-level components — compose features, handle routing
  hooks/           # Custom hooks — data fetching, local state logic
  stores/          # Global state (Zustand / Context) — minimal
  lib/             # API clients, utils, constants
  types/           # Shared TypeScript types
```

### Component Design Rules
- **Dumb components are default.** A component that only renders props is always preferred over one that fetches its own data.
- **Data fetching in hooks**, not components. Components call `useXxx()` hooks, not `fetch()` directly.
- **One responsibility per component.** If a component does layout AND data transformation AND conditional rendering AND animation, split it.
- **Colocate state.** Only lift state when 2+ components need it. Don't hoist to global store prematurely.

### When to Use Global State
Global state (Zustand/Context) is for:
- Auth session
- Theme / locale
- Notifications/toast queue
- Shopping cart (if cart is truly cross-page)

NOT for: server data (use React Query / SWR), temporary UI state (use local `useState`), form state (use React Hook Form).

### Data Fetching
- Use React Query or SWR for server state. Do not hand-roll loading/error/cache state.
- Mutations go through `useMutation`, not manual `useState` + `fetch`.
- Optimistic updates only when UX clearly benefits — don't over-engineer.

---

## 3. Cross-Cutting Patterns

### Validation: Single Source of Truth
Define schemas once with Zod. Share between frontend and backend.
```typescript
// shared/schemas/user.schema.ts
export const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});
export type CreateUserInput = z.infer<typeof CreateUserSchema>;
```

### When to Use Which Pattern

| Pattern | Use when | Avoid when |
|---|---|---|
| **Repository pattern** | DB logic is complex, needs mocking in tests | Simple CRUD with Prisma — Prisma IS already the repo |
| **CQRS** | Read and write models diverge significantly | Standard CRUD apps |
| **Event-driven** | Actions need to trigger side effects in other domains | Simple request/response flows |
| **Pub/Sub** | Async decoupling between services | Everything — don't add a message bus you don't need |
| **Saga pattern** | Distributed transactions across services | Monolith with Prisma transactions |

### Monolith First
Don't design for microservices unless you're already operating at scale that demands it. A well-structured monolith with clear domain boundaries (feature-sliced) can be extracted later. Premature service decomposition is one of the highest-cost architectural mistakes.

---

## 4. Architecture Decision Record (ADR) Mindset

When making a non-obvious architecture choice, briefly document:
1. **Context**: What problem are we solving?
2. **Decision**: What we chose.
3. **Alternatives considered**: What else was evaluated.
4. **Consequences**: What this makes easier/harder.

Even a 4-line comment block in the code is enough. The goal is future-you understanding past-you.

---

## 5. Red Flags to Surface

Always flag these when reviewing or designing:
- Services that directly import `prisma` (should go through a repo or at minimum a db module)
- Business logic inside route handlers
- God objects/services (one service doing 10 unrelated things)
- Circular dependencies between modules
- Shared mutable global state outside of a state management layer
- Hardcoded configuration (should be env vars)
- Missing error propagation (errors caught and not re-thrown or handled)

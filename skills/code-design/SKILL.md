# Code Design

Opinionated code design principles for **Oded** — TypeScript-first, function/factory over class, clean over clever.

---

## 0. The Hierarchy

```
Correct > Readable > Maintainable > DRY > Clever
```

Never sacrifice correctness or readability for cleverness. DRY is a tool, not a religion.

---

## 1. Functions and Composition Over Classes

**Default to functions.** Use classes only when you genuinely need:
- Inheritance hierarchy with shared polymorphic behavior
- Instance lifecycle with meaningful `constructor` + `destroy`
- Implementing an external interface that requires `new`

For stateless services, utilities, and business logic — factory functions are cleaner:

```typescript
// PREFERRED: factory function
export function createPaymentService(stripe: Stripe, repo: PaymentRepo) {
  async function charge(userId: string, amount: number) { ... }
  async function refund(paymentId: string) { ... }
  return { charge, refund };
}

// AVOID: class adds no value here
export class PaymentService {
  constructor(private stripe: Stripe, private repo: PaymentRepo) {}
  async charge(userId: string, amount: number) { ... }
}
```

---

## 2. DRY — When To and When Not To

**DRY is about knowledge, not syntax.**

If two pieces of code look similar but represent different concepts — **don't merge them**. They will diverge, and coupling them was a mistake.

```typescript
// These look the same today but represent different concepts — DON'T merge
function validateUserEmail(email: string) { return z.string().email().safeParse(email); }
function validateContactEmail(email: string) { return z.string().email().safeParse(email); }

// This is genuinely duplicated logic — DO merge
function validateEmail(email: string) { return z.string().email().safeParse(email); }
```

### The 3-strikes rule
- **Once**: Inline it.
- **Twice**: Note it.
- **Three times**: Abstract it.

### Over-DRY smells
- Abstractions with 3+ parameters to handle "all cases"
- Helper functions that are called in exactly one place
- Utility modules that become a dumping ground for everything
- Premature generalization before you know all the use cases

---

## 3. Naming

Names are the primary documentation. Make them earn their place.

### Functions: verb phrases
```typescript
// GOOD
getUserById, createInvoice, sendWelcomeEmail, parseQueryParams
// BAD
userById, invoice, emailHandler, queryHelper
```

### Booleans: `is`, `has`, `can`, `should`
```typescript
isAuthenticated, hasPermission, canEdit, shouldRetry
// NOT: authenticated, permission, edit, retry
```

### Don't abbreviate unless universally known
```typescript
// OK: i, id, err, ctx, req, res, db
// NOT OK: usr, cfg, mgr, svc, repo (just write it out)
```

### Avoid noise words
```typescript
// REMOVE: Manager, Handler, Helper, Util, Service (unless it's actually a service layer)
// getUser() is better than UserManager.getUser()
// parseDate() is better than DateHelper.parseDate()
```

---

## 4. Function Design

### Single responsibility
A function does one thing. If its name contains "and", it does two things.

```typescript
// BAD: does two things
async function validateAndSaveUser(input: unknown) { ... }

// GOOD: separated
async function validateUser(input: unknown): Promise<ValidatedUser> { ... }
async function saveUser(user: ValidatedUser): Promise<User> { ... }
```

### Keep it flat — early return over nesting
```typescript
// BAD: pyramid of doom
function process(user: User | null) {
  if (user) {
    if (user.isActive) {
      if (user.hasPermission) {
        doThing();
      }
    }
  }
}

// GOOD: early return
function process(user: User | null) {
  if (!user) return;
  if (!user.isActive) return;
  if (!user.hasPermission) return;
  doThing();
}
```

### Parameter count
- 0–2 params: fine
- 3 params: consider an options object
- 4+: always an options object

```typescript
// BAD
function createUser(name: string, email: string, role: string, orgId: string) {}

// GOOD
function createUser(input: { name: string; email: string; role: string; orgId: string }) {}
```

---

## 5. Types and Interfaces

### Prefer `type` over `interface` for most things
- `type` is more composable (unions, intersections, mapped types)
- `interface` is appropriate for public API contracts (open for extension)
- Be consistent within a file

### No `any`. Ever.
- Use `unknown` when type is truly unknown, then narrow it
- Use generics when type should be inferred
- Use Zod for runtime validation of external input

### Avoid type aliasing primitives with no added constraint
```typescript
// Adds no value — don't do this
type UserId = string;
type Amount = number;

// Use branded types if you need real safety
type UserId = string & { readonly __brand: 'UserId' };
```

### Prefer discriminated unions over optional fields
```typescript
// BAD: unclear which fields are present when
type Result = { data?: User; error?: string; loading?: boolean };

// GOOD: clear states
type Result =
  | { state: 'loading' }
  | { state: 'success'; data: User }
  | { state: 'error'; error: string };
```

---

## 6. Abstraction Calibration

The right level of abstraction is the one that makes the code at the call site read like prose, without hiding important behavior.

### Over-abstraction smells
- You have to read the implementation to understand what a function does
- The abstraction has more parameters than the code it wraps
- A "util" function is called in exactly one place
- You're wrapping a library 1:1 without adding behavior

### Under-abstraction smells
- The same 5-line block appears 3+ times
- Business logic lives inside route handlers or components
- No named concepts — everything is inline logic

---

## 7. Comments

### When to write comments
- **Why**, never **what**. The code says what. Comments say why.
- Non-obvious business rules: `// Must match legacy billing system format — see JIRA-1234`
- Workarounds: `// Prisma doesn't support X, using raw query`
- Gotchas: `// Order matters — middleware must run before route handlers`

### When not to write comments
- Restating the code: `// increment i` above `i++`
- Commented-out code — delete it, git has history
- `// TODO` without a ticket reference — write the ticket or fix it now

---

## 8. File and Module Design

- One primary export per file (default or named, consistent with codebase)
- File name = what it exports: `user.service.ts`, `auth.middleware.ts`, `date.utils.ts`
- Keep files under ~300 lines. If it's longer, it's doing too much.
- Barrel files (`index.ts`) are fine for re-exporting a module's public API. Don't use them as catch-alls.
- No circular dependencies. If A imports B and B imports A, extract the shared piece to C.

---

## 9. Anti-Patterns to Always Flag

- `any` type usage
- Empty catch blocks (`catch(e) {}`)
- Mutation of function parameters
- Side effects in pure functions (or functions that claim to be pure)
- Boolean trap parameters (`doThing(true, false, true)` — use an options object)
- Magic numbers/strings without named constants
- Functions longer than ~50 lines (exception: declarative data setup)
- Files longer than ~300 lines (exception: generated code)
- Importing from deep internal paths of a module instead of its public API

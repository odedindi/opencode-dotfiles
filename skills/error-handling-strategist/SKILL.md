# Error Handling Strategist

Typed, consistent, non-leaking error handling for **Oded's stack**: TypeScript, Express, Prisma, Effect-ts.

**Principle**: Errors are part of your API contract. Handle them explicitly, type them precisely, never swallow them.

---

## 0. The Two Categories of Errors

| Category | Examples | Strategy |
|---|---|---|
| **Expected errors** (domain errors) | User not found, validation failed, insufficient balance, conflict | Type them, return them, handle them at the boundary |
| **Unexpected errors** (defects) | DB connection lost, null pointer, out of memory, unhandled edge case | Log them, return a 500, do not expose internals |

Never treat expected errors as unexpected ones (generic 500). Never treat unexpected ones as expected (silently swallowing).

---

## 1. Express / TypeScript Error Architecture

### Typed error hierarchy
```typescript
// errors/app-error.ts
export class AppError extends Error {
  constructor(
    public readonly message: string,
    public readonly statusCode: number,
    public readonly code: string,
    public readonly details?: unknown
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id?: string) {
    super(
      id ? `${resource} with id '${id}' not found` : `${resource} not found`,
      404,
      'NOT_FOUND'
    );
  }
}

export class ValidationError extends AppError {
  constructor(details: { field: string; message: string }[]) {
    super('Validation failed', 400, 'VALIDATION_ERROR', details);
  }
}

export class ForbiddenError extends AppError {
  constructor(action?: string) {
    super(action ? `Not allowed to ${action}` : 'Forbidden', 403, 'FORBIDDEN');
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, 'CONFLICT');
  }
}

export class UnauthorizedError extends AppError {
  constructor() {
    super('Authentication required', 401, 'UNAUTHORIZED');
  }
}
```

### Global error middleware (single place, consistent shape)
```typescript
// middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors/app-error';
import { ZodError } from 'zod';
import { logger } from '../lib/logger';

export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  // Known domain error
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        ...(err.details ? { details: err.details } : {}),
      },
    });
  }

  // Zod validation error (from middleware or direct parse)
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid input',
        details: err.errors.map(e => ({ field: e.path.join('.'), message: e.message })),
      },
    });
  }

  // Prisma known errors (foreign key, unique constraint)
  if (isPrismaError(err)) {
    return handlePrismaError(err, res);
  }

  // Unexpected error — log full details, return generic message
  logger.error({ err, path: req.path, method: req.method }, 'Unhandled error');
  return res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
    },
  });
}
```

---

## 2. Prisma Error Handling

Prisma throws typed errors — handle them specifically:

```typescript
import { Prisma } from '@prisma/client';

function isPrismaError(err: unknown): err is Prisma.PrismaClientKnownRequestError {
  return err instanceof Prisma.PrismaClientKnownRequestError;
}

function handlePrismaError(err: Prisma.PrismaClientKnownRequestError, res: Response) {
  switch (err.code) {
    case 'P2002': // Unique constraint violation
      return res.status(409).json({
        error: { code: 'CONFLICT', message: 'A record with this value already exists' },
      });
    case 'P2025': // Record not found (e.g., update/delete on non-existent)
      return res.status(404).json({
        error: { code: 'NOT_FOUND', message: 'Record not found' },
      });
    case 'P2003': // Foreign key constraint
      return res.status(400).json({
        error: { code: 'INVALID_REFERENCE', message: 'Referenced record does not exist' },
      });
    default:
      return res.status(500).json({
        error: { code: 'INTERNAL_ERROR', message: 'Database error' },
      });
  }
}
```

---

## 3. Effect-ts Error Handling

In Effect-ts, errors are part of the type signature — use tagged errors for precise handling.

```typescript
import { Effect, Data } from 'effect';

// Define typed errors as tagged classes
class UserNotFoundError extends Data.TaggedError('UserNotFoundError')<{
  userId: string;
}> {}

class InsufficientBalanceError extends Data.TaggedError('InsufficientBalanceError')<{
  required: number;
  available: number;
}> {}

// Service returns typed error union in E channel
const getUser = (id: string): Effect.Effect<User, UserNotFoundError> =>
  Effect.tryPromise({
    try: () => prisma.user.findUniqueOrThrow({ where: { id } }),
    catch: () => new UserNotFoundError({ userId: id }),
  });

// Handle specific errors
const result = await Effect.runPromise(
  getUser(userId).pipe(
    Effect.catchTag('UserNotFoundError', (err) =>
      Effect.fail(new NotFoundError('User', err.userId)) // convert to AppError
    )
  )
);
```

### Effect error → Express boundary conversion
```typescript
// At the route handler boundary, convert Effect errors to HTTP responses
app.get('/users/:id', async (req, res, next) => {
  const result = await Effect.runPromise(
    getUserEffect(req.params.id).pipe(
      Effect.catchTag('UserNotFoundError', (e) =>
        Effect.fail(new NotFoundError('User', e.userId))
      ),
      Effect.either // wrap in Either so we can inspect without throwing
    )
  );

  if (result._tag === 'Left') return next(result.left); // pass to error middleware
  return res.json(result.right);
});
```

---

## 4. Async Error Handling in Express

Express 4 doesn't catch async errors by default — you must forward them:

```typescript
// Wrapper to catch async errors automatically
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}

// Usage
app.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await userService.getUser(req.params.id); // throws NotFoundError
  res.json(user); // error automatically forwarded to error middleware
}));
```

> **Note**: Express 5 handles async errors natively — no wrapper needed.

---

## 5. Anti-Patterns to Always Flag

```typescript
// ❌ Empty catch block — silent failure
try {
  await sendEmail(user.email);
} catch (e) {}

// ❌ Catching and re-wrapping with loss of information
try { ... } catch (e) { throw new Error('Something failed'); }

// ❌ Returning null instead of throwing for not-found
async function getUser(id: string): Promise<User | null> { ... }
// Caller forgets null check → silent null propagation
// Prefer: throw NotFoundError or use Option type

// ❌ console.error + ignore
catch (e) { console.error(e); } // error not propagated to caller

// ❌ Checking .message string for error type
if (err.message.includes('not found')) { ... } // fragile

// ✅ Type-check the error
if (err instanceof NotFoundError) { ... }
```

---

## 6. Error Logging Standards

Log at the right level:
- `error`: unexpected failures, 5xx responses
- `warn`: expected but notable (rate limit hit, retried operation)
- `info`: business events (user created, payment processed)
- `debug`: developer-only detail (query params, response size)

Always include structured context, never concatenate strings:
```typescript
// ❌
logger.error('Failed to process payment for user ' + userId + ': ' + err.message);

// ✅
logger.error({ userId, orderId, err }, 'Payment processing failed');
```

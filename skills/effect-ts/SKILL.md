# Effect-ts Guide

This skill covers Effect-ts patterns for **Oded** — a TypeScript engineer coming from Promise/async-await who is actively exploring Effect-ts.

**Context**: Effect-ts is a paradigm shift. Don't try to map it 1:1 to Promise-based code — the mental model is fundamentally different.

---

## The Core Mental Model Shift

| Concept | Promise/async | Effect-ts |
|---|---|---|
| Computation | Eager (runs immediately) | Lazy (description of program) |
| Errors | `try/catch`, untyped | Typed error channel `Effect<A, E, R>` |
| Dependencies | Import directly | Declared in `R` (requirements) |
| Concurrency | `Promise.all` etc. | Fibers, `Effect.all`, `Stream` |
| Resources | `finally` blocks | `Scope`, `Layer`, managed lifetimes |

```typescript
// Promise: runs immediately, errors are untyped
const result: Promise<User> = fetchUser(id)  // fires now

// Effect: description of a program, runs when you interpret it
const program: Effect.Effect<User, NotFoundError | DbError, UserRepo> = 
  UserRepo.pipe(
    Effect.flatMap(repo => repo.findById(id))
  )
// Nothing runs until you call Effect.runPromise(program)
```

---

## The Three Type Parameters

```typescript
Effect<A, E, R>
//      ^  ^  ^
//      |  |  +-- Requirements (dependencies, like a Reader monad)
//      |  +-- Error channel (typed failures)
//      +-- Success type
```

### Reading Effect types

```typescript
// "A program that needs UserRepo, can fail with NotFoundError, succeeds with User"
Effect.Effect<User, NotFoundError, UserRepo>

// "Pure computation, no deps, no typed errors"
Effect.Effect<number, never, never>

// Shorthand: Effect.Effect<A> means <A, never, never>
```

---

## Core Operations

### Creating Effects

```typescript
import { Effect } from 'effect'

// From value (success)
const success = Effect.succeed(42)

// From typed error (failure)
const failure = Effect.fail(new NotFoundError('user not found'))

// From synchronous computation (catches thrown errors as defects)
const sync = Effect.sync(() => JSON.parse(input))

// From async computation
const async = Effect.promise(() => fetch('/api/data'))

// From async that can fail with typed error
const asyncFailible = Effect.tryPromise({
  try: () => db.user.findUniqueOrThrow({ where: { id } }),
  catch: (e) => new DbError(String(e))
})

// From callback-style async
const fromCallback = Effect.async<string, Error>((resume) => {
  someCallbackFn((err, data) => {
    if (err) resume(Effect.fail(err))
    else resume(Effect.succeed(data))
  })
})
```

### Transforming Effects

```typescript
// map: transform success value (like Promise.then for values)
Effect.map(effect, (value) => value * 2)

// flatMap: chain effects (like Promise.then that returns a Promise)
Effect.flatMap(effect, (value) => anotherEffect(value))

// pipe style (preferred)
const program = Effect.succeed(5).pipe(
  Effect.map(n => n * 2),
  Effect.flatMap(n => Effect.succeed(`Result: ${n}`)),
  Effect.tap(str => Effect.log(str)),  // side effect, doesn't change value
)

// tap: run an effect for side effects, pass through the value
// mapError: transform error channel
// catchAll: recover from any error
// catchTag: recover from specific tagged errors
```

### Error Handling

```typescript
// Tagged errors — use Data.TaggedError for discriminated union behavior
import { Data } from 'effect'

class NotFoundError extends Data.TaggedError('NotFoundError')<{
  id: string
}> {}

class ValidationError extends Data.TaggedError('ValidationError')<{
  message: string
  field: string
}> {}

// catchTag: handle specific error type
const program = findUser(id).pipe(
  Effect.catchTag('NotFoundError', (err) => 
    Effect.succeed(defaultUser)  // recover
  )
)

// catchAll: handle all errors
const safe = program.pipe(
  Effect.catchAll((err) => Effect.succeed(null))
)

// mapError: transform error type
const mapped = program.pipe(
  Effect.mapError((err) => new AppError(err.message))
)
```

---

## Services and Dependency Injection

The `R` (Requirements) channel is Effect's DI system.

### Defining a Service

```typescript
import { Context, Effect, Layer } from 'effect'

// 1. Define the service interface
class UserRepo extends Context.Tag('UserRepo')<
  UserRepo,
  {
    findById: (id: string) => Effect.Effect<User, NotFoundError>
    create: (data: CreateUserData) => Effect.Effect<User, DbError>
  }
>() {}

// 2. Implement the service (a Layer)
const UserRepoLive = Layer.effect(
  UserRepo,
  Effect.gen(function* () {
    const db = yield* Database  // UserRepoLive requires Database
    return {
      findById: (id) => Effect.tryPromise({
        try: () => db.user.findUniqueOrThrow({ where: { id } }),
        catch: () => new NotFoundError({ id })
      }),
      create: (data) => Effect.tryPromise({
        try: () => db.user.create({ data }),
        catch: (e) => new DbError({ cause: e })
      })
    }
  })
)
```

### Using a Service

```typescript
// Consuming a service in a program
const getUser = (id: string): Effect.Effect<User, NotFoundError, UserRepo> =>
  UserRepo.pipe(
    Effect.flatMap(repo => repo.findById(id))
  )

// Or with Effect.gen (like async/await but for Effect)
const getUser = (id: string) =>
  Effect.gen(function* () {
    const repo = yield* UserRepo
    const user = yield* repo.findById(id)
    return user
  })
```

### Effect.gen — The async/await of Effect

```typescript
// Effect.gen uses generator syntax — think of yield* as await
const program = Effect.gen(function* () {
  const repo = yield* UserRepo          // get service from context
  const user = yield* repo.findById(id) // run an effect, get result
  const posts = yield* PostRepo.pipe(
    Effect.flatMap(r => r.findByUserId(user.id))
  )
  return { user, posts }
})
// Type: Effect.Effect<{user, posts}, NotFoundError, UserRepo | PostRepo>
```

---

## Layers — Dependency Wiring

Layers are how you compose and provide services.

```typescript
// Compose layers
const AppLive = Layer.mergeAll(
  UserRepoLive,
  PostRepoLive,
  DatabaseLive,
)

// Provide layer to a program to resolve requirements
const runnable = Effect.provide(program, AppLive)

// Run the program
Effect.runPromise(runnable)
```

---

## Concurrency

```typescript
// Run effects in parallel (like Promise.all)
const [users, posts] = yield* Effect.all(
  [fetchUsers(), fetchPosts()],
  { concurrency: 'unbounded' }
)

// Run with bounded concurrency
const results = yield* Effect.all(
  items.map(item => processItem(item)),
  { concurrency: 10 }
)

// Race (first to succeed wins)
const first = yield* Effect.race(effect1, effect2)

// Fork: run in background fiber
const fiber = yield* Effect.fork(backgroundTask)
// ... do other work ...
const result = yield* Fiber.join(fiber)
```

---

## Resource Management (Scope)

```typescript
import { Effect, Scope } from 'effect'

// acquireRelease: ensures cleanup always runs
const managedConnection = Effect.acquireRelease(
  Effect.promise(() => db.connect()),    // acquire
  (conn) => Effect.promise(() => conn.close())  // release (always runs)
)

// Use in program
const program = Effect.scoped(
  Effect.gen(function* () {
    const conn = yield* managedConnection
    // conn is open here
    const result = yield* queryWithConnection(conn)
    // conn automatically closed when scope ends
    return result
  })
)
```

---

## Schema (Zod equivalent in Effect ecosystem)

```typescript
import { Schema } from 'effect'

const UserSchema = Schema.Struct({
  id: Schema.UUID,
  email: Schema.String.pipe(Schema.pattern(/^.+@.+\..+$/)),
  name: Schema.String.pipe(Schema.minLength(1)),
  role: Schema.Literal('admin', 'user', 'guest'),
})

type User = Schema.Schema.Type<typeof UserSchema>

// Parse (returns Effect)
const parseUser = Schema.decodeUnknown(UserSchema)
const user = yield* parseUser(rawData)
```

---

## Migrating from Promise-based Code

### Pattern: Simple async function

```typescript
// Before (Promise)
async function getUser(id: string): Promise<User> {
  const user = await db.user.findUnique({ where: { id } })
  if (!user) throw new Error('Not found')
  return user
}

// After (Effect)
const getUser = (id: string): Effect.Effect<User, NotFoundError> =>
  Effect.tryPromise({
    try: () => db.user.findUniqueOrThrow({ where: { id } }),
    catch: () => new NotFoundError({ id })
  })
```

### Pattern: Multiple async operations

```typescript
// Before
async function createPost(userId: string, data: CreatePostData) {
  const user = await getUser(userId)
  const post = await db.post.create({ data: { ...data, userId: user.id } })
  await sendNotification(user.email, post.id)
  return post
}

// After
const createPost = (userId: string, data: CreatePostData) =>
  Effect.gen(function* () {
    const user = yield* getUser(userId)
    const post = yield* Effect.tryPromise({
      try: () => db.post.create({ data: { ...data, userId: user.id } }),
      catch: (e) => new DbError({ cause: e })
    })
    yield* Effect.fork(sendNotification(user.email, post.id))  // fire and forget
    return post
  })
```

---

## Common Pitfalls

```typescript
// PITFALL: Using Promise inside Effect (breaks the abstraction)
// WRONG:
const bad = Effect.sync(() => {
  somePromise.then(...)  // Don't mix
})

// RIGHT: wrap promises with Effect.promise or Effect.tryPromise

// PITFALL: Throwing inside Effect.sync
// WRONG:
const bad = Effect.sync(() => {
  if (!user) throw new Error('not found')  // becomes a defect (untyped)
})
// RIGHT: use Effect.fail for typed errors

// PITFALL: Forgetting that Effect is lazy
const effect = Effect.succeed(console.log('hello'))  // 'hello' printed immediately!
// RIGHT:
const effect = Effect.sync(() => console.log('hello'))  // prints when run

// PITFALL: Using Effect.runPromise inside an Effect
// Never call Effect.run* inside an Effect — compose instead
```

---

## Running Programs

```typescript
// Development / scripts
Effect.runPromise(program)

// Production (with layer provision)
Effect.runPromise(
  program.pipe(Effect.provide(AppLive))
)

// Sync (only for pure effects, no async)
Effect.runSync(Effect.succeed(42))

// Full run with error handler
Effect.runPromiseExit(program).then((exit) => {
  if (Exit.isSuccess(exit)) console.log(exit.value)
  else console.error(exit.cause)
})
```

---

## When to Use Effect-ts

**Good fit:**
- Complex async orchestration with typed errors
- Code with many dependency injections (services, DB, config)
- Long-running processes needing resource management
- Concurrent operations with complex error handling

**Overkill:**
- Simple CRUD Express routes (stick with Promise + Zod)
- Scripts and one-off utilities
- Where the team isn't already familiar with Effect

**Oded's current stage**: Learning Effect-ts → prefer patterns with `Effect.gen` and simple `Layer` composition. Avoid deep `Fiber`/`Stream` usage until comfortable with core concepts.

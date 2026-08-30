# Testing Strategy

Testing guidance for **Oded's stack**: TypeScript, Express, React, Prisma, Vitest/Jest.

**Philosophy**: Test behavior, not implementation. Mock at process boundaries only. Never mock what you own.

---

## 0. The Core Rule

> **Test the contract, not the code.**

A test that breaks when you rename an internal variable is a bad test. A test that breaks when observable behavior changes is a good test.

---

## 1. What to Test (and What Not To)

### ✅ Always Test

| What | Why |
|---|---|
| Pure business logic (services, utils) | Highest ROI — fast, no I/O, easy to set up |
| API endpoints (integration) | Verifies the full HTTP contract including validation and error codes |
| Complex conditional logic | Any function with 3+ branches |
| Data transformations | Input → output mappings that are easy to get wrong |
| Edge cases on critical paths | Null inputs, empty arrays, boundary values on business rules |

### ❌ Don't Test

| What | Why not |
|---|---|
| Prisma's own query behavior | Prisma tests its own library |
| Simple getters/setters with no logic | Zero ROI |
| Implementation details (internal method calls) | Breaks on refactor, tests nothing meaningful |
| Third-party library behavior | Not your code |
| Framework wiring (Express route registration) | Integration tests cover this |
| UI snapshot tests by default | Brittle, low signal-to-noise |

### 🤔 Test Selectively

| What | When to test |
|---|---|
| React components | When they contain logic (conditional rendering, computed values). Not for pure display. |
| DB queries | Only via integration tests against a real (test) DB, never mocked. |
| Utility functions | Only if they have logic. Don't test `formatDate` if it's a one-liner wrapping `date-fns`. |

---

## 2. Test Pyramid for This Stack

```
         [E2E]        ← Few (5-20). Playwright. Happy path + critical flows only.
       [Integration]  ← Medium (20-50 per service). HTTP tests with real DB.
     [Unit]           ← Many (50-200). Pure logic, fast, no I/O.
```

### Unit Tests
- Target: pure service functions, utilities, validators, transformations
- Setup: minimal — just call the function
- No DB, no HTTP, no filesystem
- Run in <5ms each

### Integration Tests (Backend)
- Target: Express route handlers end-to-end (request → DB → response)
- Use a real test database (separate schema or SQLite in-memory)
- Use `supertest` to make HTTP requests
- Seed minimal data in `beforeEach`, clean up in `afterEach`
- Test: status codes, response shape, DB state changes, error responses

```typescript
// integration test pattern
describe('POST /users', () => {
  it('creates a user and returns 201', async () => {
    const res = await request(app)
      .post('/users')
      .send({ email: 'test@example.com', name: 'Test' });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ email: 'test@example.com' });

    const user = await prisma.user.findUnique({ where: { email: 'test@example.com' } });
    expect(user).not.toBeNull();
  });
});
```

### E2E Tests (Playwright)
- Target: full user flows in the browser
- Only cover: critical business flows (signup, checkout, core CRUD)
- Don't cover: every permutation (that's integration test territory)
- Run in CI, not on every local save

---

## 3. Mocking Rules

### Mock Only at Process Boundaries

| Boundary | Mock strategy |
|---|---|
| External HTTP API (Stripe, SendGrid, etc.) | Mock at the HTTP call level (msw or similar) |
| Email/SMS sending | Mock the transport function |
| File system | Only if I/O is the bottleneck; prefer temp dirs |
| Time (`Date.now()`, `new Date()`) | Mock via dependency injection or vi.setSystemTime |
| Randomness (`Math.random()`, `crypto`) | Inject a seed or mock the function |

### Never Mock
- Your own service functions (test them directly)
- Prisma (use a real test DB)
- Internal modules you own
- React components (test them directly or via their parent)

### Why: Mocking internal modules creates tests that pass even when the code is broken. The mock is the thing that "works", not your code.

---

## 4. Test Structure (AAA Pattern)

Every test follows **Arrange → Act → Assert**:

```typescript
it('returns 404 when user does not exist', async () => {
  // Arrange
  const nonExistentId = 'user_does_not_exist';

  // Act
  const res = await request(app).get(`/users/${nonExistentId}`);

  // Assert
  expect(res.status).toBe(404);
  expect(res.body).toMatchObject({ code: 'NOT_FOUND' });
});
```

No multi-assertion sprawl. One behavior per test. Test names are sentences: `'returns 404 when user does not exist'`, not `'user not found'`.

---

## 5. Database Testing (Prisma)

### Never mock Prisma. Use a real test database.

Options (in order of preference):
1. **Separate test schema in PostgreSQL** — fast, isolated, parallel-safe with `prisma db push --schema`
2. **SQLite in-memory** — only works if you're not using Postgres-specific features
3. **Docker Compose test DB** — good for CI

### Test DB Setup Pattern
```typescript
// vitest.setup.ts
import { prisma } from '../src/db';

beforeEach(async () => {
  // clean in dependency order to avoid FK violations
  await prisma.post.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});
```

### Seeding Factories
Use factory functions for test data, not copy-pasted objects:
```typescript
export function buildUser(overrides: Partial<User> = {}): CreateUserInput {
  return {
    email: `test-${Date.now()}@example.com`,
    name: 'Test User',
    ...overrides,
  };
}
```

---

## 6. React Component Testing

Use **React Testing Library**. Test from the user's perspective.

### Do:
```typescript
// Test: does the user see what they should?
it('shows error message when form submitted without email', async () => {
  render(<SignupForm />);
  await userEvent.click(screen.getByRole('button', { name: /sign up/i }));
  expect(screen.getByText(/email is required/i)).toBeInTheDocument();
});
```

### Don't:
```typescript
// Don't test internal state or implementation details
expect(wrapper.state('isLoading')).toBe(true); // ❌
expect(component.find('Spinner').exists()).toBe(true); // ❌ (unless Spinner is the contract)
```

### When to test components:
- Conditional rendering logic
- User interactions that change state
- Form validation
- Computed/derived display values

When NOT to: pure display components with no logic. Rely on visual review + E2E.

---

## 7. What Good Test Coverage Looks Like

**Don't aim for 100% coverage.** Aim for coverage of behavior that matters.

- Lines coverage is a vanity metric
- Branch coverage on business logic is meaningful
- "Is this function tested for its common failure modes?" is the right question

A codebase with 60% coverage where every critical path is tested is better than 95% coverage where most tests just invoke trivial getters.

---

## 8. Test File Conventions

```
src/
  features/users/
    users.service.ts
    users.service.test.ts     # unit tests, same dir
  tests/
    integration/
      users.test.ts           # integration tests (HTTP)
    e2e/
      signup.spec.ts          # Playwright
```

- Unit tests colocated with the module they test
- Integration tests in `tests/integration/`
- E2E tests in `tests/e2e/`

# Conventional Commits

Enforce the Conventional Commits specification for **Oded's** Git workflow. Clean, parseable, semantic history.

---

## 0. The Spec (Compact)

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

Every commit message must follow this format. No exceptions.

---

## 1. Types

| Type | When to use |
|---|---|
| `feat` | A new feature visible to users or API consumers |
| `fix` | A bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build process, dependency updates, tooling, config |
| `ci` | CI/CD pipeline changes |
| `style` | Formatting, whitespace, missing semicolons (no logic change) |
| `revert` | Reverts a previous commit |

**Rules:**
- `feat` and `fix` are the only types that appear in changelogs. Don't over-use them.
- `refactor` is NOT `chore`. Refactor changes production code.
- `chore` is for everything that doesn't touch production app logic.

---

## 2. Scope

Optional but recommended. The module, feature, or layer affected:

```
feat(auth): add refresh token rotation
fix(billing): prevent duplicate charge on retry
refactor(users): extract validation to service layer
chore(deps): upgrade Prisma to 6.2.0
ci(github-actions): add node matrix for 18 and 20
```

Keep scopes consistent within a project. Establish 5-10 scopes and stick to them.
Common scopes for this stack: `auth`, `users`, `billing`, `api`, `db`, `frontend`, `deps`, `config`, `middleware`

---

## 3. Description

- Imperative mood: "add", "fix", "remove" — not "added", "fixed", "removes"
- Lowercase first letter
- No period at the end
- ≤72 characters
- Says WHAT changed, not HOW

```
# GOOD
feat(auth): add refresh token rotation
fix(users): prevent duplicate email on concurrent signup
refactor(posts): move pagination logic to repository layer

# BAD
feat(auth): Added the refresh token rotation feature.  ← past tense + period
fix: fixed a bug  ← vague
feat: WIP  ← not a real commit
```

---

## 4. Body (optional)

Add a body when the WHY is not obvious from the description:

```
fix(billing): prevent double charge on payment retry

Stripe's idempotency key was not being set on retry attempts,
causing duplicate charges when the network request timed out.
Added idempotencyKey derived from the order ID to all charge calls.

Fixes #482
```

Separate from description with a blank line. Wrap at 72 characters.

---

## 5. Footer (optional)

```
BREAKING CHANGE: <description>   ← triggers major version bump
Fixes #123                        ← closes issue
Refs #456                         ← references without closing
Co-authored-by: Name <email>      ← pair programming
```

**BREAKING CHANGE** must appear in the footer (not the description) to be parsed correctly by tooling.

```
feat(api)!: remove deprecated /v1/users/search endpoint

BREAKING CHANGE: The /v1/users/search endpoint has been removed.
Use /v1/users?q= instead.
```

The `!` after the type/scope is an alternative shorthand for breaking changes.

---

## 6. Semantic Versioning Alignment

Conventional Commits maps directly to semver:

| Commit type | Version bump |
|---|---|
| `BREAKING CHANGE` or `!` | Major (`1.0.0` → `2.0.0`) |
| `feat` | Minor (`1.0.0` → `1.1.0`) |
| `fix`, `perf`, everything else | Patch (`1.0.0` → `1.0.1`) |

---

## 7. Multi-Commit PR Strategy

Each commit should be atomic — one logical change. PR history should read like a story:

```
chore(deps): upgrade Prisma to 6.2.0
feat(db): add user soft-delete migration
feat(users): add soft-delete to user repository
feat(api): expose DELETE /users/:id as soft-delete
test(users): add tests for soft-delete behavior
docs(api): update DELETE /users/:id documentation
```

Not:
```
WIP
fixes
more fixes
done
```

---

## 8. When Writing Commit Messages for Oded

1. Read the diff or staged changes
2. Identify the PRIMARY change (one commit = one concern)
3. Pick the right `type` — when in doubt between `feat` and `refactor`, ask: "does this add user-visible value?"
4. Choose a scope from the project's established scopes
5. Write the description in imperative mood, ≤72 chars
6. Add body if the WHY isn't obvious
7. Add `BREAKING CHANGE` footer if any public contract changed

---

## 9. Common Mistakes to Correct

| Bad | Corrected |
|---|---|
| `update stuff` | `chore: update dependencies and config` |
| `bug fix` | `fix(auth): correct token expiry comparison` |
| `added feature` | `feat(posts): add draft post support` |
| `refactoring` | `refactor(users): extract email validation to util` |
| `misc changes` | Split into multiple atomic commits |
| `fix tests` | `test(users): fix flaky email uniqueness test` |

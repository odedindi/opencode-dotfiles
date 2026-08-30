# Oded's AI Coding Assistant Skills

Personal skill library for [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) / OpenCode.

Skills are markdown files loaded as context into every agent session. Each skill is opinionated and tailored to a specific domain of my daily engineering work.

## Setup on a New Machine

```bash
git clone git@github.com:odedindi/SKILLS.git ~/.config/opencode/skills
```

That's it. oh-my-opencode auto-discovers skills from `~/.config/opencode/skills/*/SKILL.md`.

## Syncing Changes

```bash
cd ~/.config/opencode/skills
git add <skill-dir>/SKILL.md
git commit -m "chore(skills): update <skill-name>"
git push
```

On other machines: `git pull`

---

## Skill Index

### Core Stack

| Skill | Description |
|---|---|
| [`typescript-fullstack`](./typescript-fullstack/SKILL.md) | Strict TS patterns, Zod, React hooks/components, Express middleware, Prisma |
| [`effect-ts`](./effect-ts/SKILL.md) | Effect-ts mental model — `Effect<A,E,R>`, tagged errors, services, Layers, Effect.gen |
| [`rust-learner`](./rust-learner/SKILL.md) | TypeScript→Rust mapping, ownership, ecosystem (tokio, axum, serde, sqlx) |

### Database

| Skill | Description |
|---|---|
| [`db-query-optimizer`](./db-query-optimizer/SKILL.md) | PostgreSQL indexes, EXPLAIN ANALYZE, Prisma N+1, cursor pagination, MongoDB, SQLite |

### Frontend

| Skill | Description |
|---|---|
| [`react-render-optimizer`](./react-render-optimizer/SKILL.md) | useMemo/useCallback, reconciliation, preventing unnecessary re-renders |
| [`accessibility-advocate`](./accessibility-advocate/SKILL.md) | WCAG 2.1 AA, semantic HTML, ARIA, keyboard nav, Tailwind a11y utilities |

### Architecture & Design

| Skill | Description |
|---|---|
| [`software-architect`](./software-architect/SKILL.md) | Layered vs feature-sliced arch, layer boundaries, DI without framework |
| [`code-design`](./code-design/SKILL.md) | Functions over classes, naming, DRY calibration, anti-patterns |
| [`testing-strategy`](./testing-strategy/SKILL.md) | What to test, minimal mocking, real DB testing, React Testing Library |
| [`algorithm-optimizer`](./algorithm-optimizer/SKILL.md) | Big-O analysis, sliding window, two-pointer, DP, graph traversal, profiling |

### API & Security

| Skill | Description |
|---|---|
| [`api-contract-designer`](./api-contract-designer/SKILL.md) | REST consistency — naming, pagination, error shapes, versioning |
| [`security-auditor`](./security-auditor/SKILL.md) | OWASP Top 10, secrets management, auth patterns, input validation |
| [`error-handling-strategist`](./error-handling-strategist/SKILL.md) | Typed error hierarchy, Prisma errors, Effect-ts errors, Express middleware |

### Workflow & Process

| Skill | Description |
|---|---|
| [`roi-lens`](./roi-lens/SKILL.md) | MVP-first, YAGNI, scope creep detection, 80/20, reversibility framework |
| [`pr-storyteller`](./pr-storyteller/SKILL.md) | PR descriptions from git diff — context, risk, testing steps |
| [`conventional-commits`](./conventional-commits/SKILL.md) | Conventional Commits spec, semantic versioning alignment |
| [`code-reviewer-persona`](./code-reviewer-persona/SKILL.md) | Senior reviewer checklist — correctness, backwards compat, edge cases |
| [`regression-dog`](./regression-dog/SKILL.md) | Behavioral diff detection — no test runs, pure code reasoning |

---

## Adding a New Skill

```bash
mkdir -p ~/.config/opencode/skills/my-skill
# write SKILL.md
git add my-skill/SKILL.md
git commit -m "feat(skills): add my-skill"
git push
```

Skills are plain markdown. No frontmatter required.

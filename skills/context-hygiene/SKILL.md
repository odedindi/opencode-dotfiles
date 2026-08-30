# Context Hygiene

The context window is finite and precious. Every token of noise is a token of signal lost.

**Core rule**: The right context wins over more context. Always.

---

## 0. The Mental Model

Think of the context window as working memory. Filling it with irrelevant files, verbose outputs, and stale history degrades every subsequent response. Keeping it focused keeps the AI sharp.

A 200K token window sounds huge until you realize:
- A 300-line TypeScript file ≈ 2,500 tokens
- Loading 10 files fills ~25K tokens — re-processed on every turn
- Long conversation history consumes 40–50% of the window by mid-session
- Tool outputs (test runs, build logs) can dump 5–20K tokens in one shot

---

## 1. One Task Per Session

**Rule**: Each session = one unit of work. One bug, one feature, one refactor.

When the task is done or you're switching context, start a fresh session.

**Why**: Carrying irrelevant history from a previous task forces the AI to process dead context on every turn. It also causes earlier file contents to "fall off" the effective window, leading to hallucinations about code it no longer sees.

**The Checkpoint Pattern** — before ending a long session:
> "Summarize the key decisions, findings, and unresolved questions from this session in a brief paragraph I can paste into the next one."

Save that summary. Paste it as the first message in the next session. Clean slate, no lost context.

---

## 2. Load Chunks, Not Directories

**Wrong**: "Look at the `src/` folder and find the auth bug."  
**Right**: "Read `src/auth/jwt.service.ts` lines 45–90 — the `verifyToken` function."

**Wrong**: Pasting an entire 500-line file when only one function matters.  
**Right**: Read the specific function. Use `lsp_goto_definition` to jump directly to it.

**Rule**: Before loading a file, ask — "what's the minimum I need to read?" Use `lsp_symbols(scope="document")` to get an outline first, then read only the relevant section with `read(offset=X, limit=Y)`.

---

## 3. Mute Verbose Tool Outputs

Never dump massive stdout into context. Filter at the source.

```bash
# ❌ Dumps entire failing test suite — potentially 10K+ tokens
npm test

# ✅ Run only the relevant test file
npm test -- --testPathPattern="auth.service"

# ❌ Full git log
git log --all

# ✅ Scoped
git log -n 10 --oneline
git diff HEAD~1 -- src/auth/

# ❌ All diagnostics across the project
# ✅ Diagnostics scoped to changed files
lsp_diagnostics(filePath="src/auth/", extension=".ts", severity="error")
```

---

## 4. Intent Context vs State Context

Every prompt needs **both** — most bad sessions have too much State and not enough Intent.

| Type | What it is | Examples |
|---|---|---|
| **Intent** | What you want, why, constraints | "Fix the race condition without changing the API shape. No new dependencies." |
| **State** | Current code, errors, environment | The stack trace, the relevant function, the DB schema |

**Recipe for a well-loaded session**:
1. State the intent first (what + why + constraints)
2. Provide the minimal state (relevant files/functions/errors)
3. Specify the verification criteria (how you'll know it worked)

---

## 5. What NOT to Put in Context

| Never put in context | Why |
|---|---|
| `.env` files | Secret leakage — keys end up in responses, logs, or prompt injection attacks |
| Full DB dumps or production logs with real user data | PII leakage, privacy violation |
| Entire `node_modules/` or build artifacts | Pure noise — thousands of tokens, zero signal |
| Unrelated open files | The AI treats everything in context as potentially relevant |
| Untrusted external data (user-submitted JSON, third-party payloads) | Prompt injection risk — malicious instructions can be embedded |

---

## 6. Context Budgeting for Long Tasks

For tasks spanning many files:

1. **Orient first, don't load everything**: Use `lsp_symbols(scope="workspace")` and `glob` to map the territory before reading files.
2. **Sequence your reads**: Load files as you need them, not all upfront.
3. **Summarize completed steps**: After finishing a subtask, briefly summarize what was done before moving on. This compresses history.
4. **Use todos as external memory**: The todo list lives outside the context window. Use it to track progress so you don't need to re-read history to know where you are.

---

## 7. Signs Your Context is Degraded

Watch for these in responses — they mean it's time to reset:

- AI refers to a file or function it previously read but now gets wrong
- AI repeats suggestions it already made (loop)
- Responses become vague or hedge with "I'm not sure about the full codebase"
- AI ignores constraints stated earlier in the session
- Response quality noticeably drops compared to session start

**When you see these**: checkpoint, start a new session, paste the summary.

---

## 8. Context Hygiene Checklist (Before Starting a Session)

- [ ] Is this a single, focused task? If not, split it.
- [ ] Do I know which specific files/functions are relevant? (Don't load "everything")
- [ ] Are there any secrets or PII I might accidentally include?
- [ ] Do I have a clear verification criteria for "done"?
- [ ] Is this a continuation? If so, do I have the checkpoint summary ready?

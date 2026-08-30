# Tool Navigator

Know your tools. Use the right one. Don't reach for an external MCP when a built-in solves it.

---

## 0. Principle

Every tool has a cost — tokens, latency, external calls. Always use the cheapest tool that solves the problem. Check built-ins first, then LSP, then AST, then MCP, then web.

---

## 1. Built-in Tool Hierarchy (Cheapest → Most Expensive)

### Tier 1 — Zero Cost (Pure Local)
| Tool | Best For | When NOT to Use |
|---|---|---|
| `read` | Reading known files at known paths | Exploring unknown structure |
| `glob` | Finding files by name pattern | Finding files by content |
| `grep` | Finding content by regex across files | Semantic understanding of code |
| `edit` / `write` | Making precise file changes | When you haven't read the file first |
| `lsp_diagnostics` | Type errors, lint issues before/after changes | Running a full build — use this instead |

### Tier 2 — LSP (Semantic, Fast, Local)
Always prefer LSP over grep/read for code navigation. LSP understands the AST — grep does not.

| Tool | Use For |
|---|---|
| `lsp_goto_definition` | Jump to where a symbol is defined — never grep for a function name |
| `lsp_find_references` | **MANDATORY before any rename or delete** — find all usages |
| `lsp_symbols (document)` | Get outline of a large file without reading all of it |
| `lsp_symbols (workspace)` | Locate a class/function across the entire project |
| `lsp_prepare_rename` → `lsp_rename` | Safe cross-workspace rename — never use sed/ast_grep for this |
| `lsp_diagnostics` | Validate changes without running build — use after EVERY edit |

**LSP decision rule**: If you're about to grep for a function name, symbol, or type — use LSP instead.

### Tier 3 — AST-Grep (Structural, Pattern-Based)
Use when you need to match or transform *code structure*, not just text.

```bash
# Find all async functions across the codebase
ast_grep_search pattern="async function $NAME($$$) { $$$ }" lang="typescript"

# Rename a pattern safely (dry-run first)
ast_grep_replace pattern="console.log($MSG)" rewrite="logger.info($MSG)" lang="typescript" dryRun=true
```

**AST decision rule**: If grep would work but might match comments/strings/wrong context, use ast_grep.

### Tier 4 — Web & External Search
| Tool | Use For |
|---|---|
| `context7_resolve-library-id` + `context7_query-docs` | Official, versioned library docs (always try this before web search) |
| `grep_app_searchGitHub` | Real-world production code examples for a pattern |
| `websearch_web_search_exa` | Current info, news, or when Context7 has no results |
| `webfetch` | Crawl a specific URL for docs or config examples |

---

## 2. LSP Usage Patterns

### Before refactoring — always check impact first
```
1. lsp_symbols(scope="workspace", query="MyFunction")  → find it
2. lsp_find_references(...)                             → see all usages
3. lsp_goto_definition(...)                             → read the source
4. make the change
5. lsp_diagnostics(...)                                 → validate, no build needed
```

### Safe rename workflow
```
1. lsp_prepare_rename(file, line, char)   → verify it's valid
2. lsp_rename(file, line, char, newName)  → applies to ALL files automatically
3. lsp_diagnostics(dir, extension=".ts") → confirm no errors introduced
```

### Unknown codebase — quick orientation
```
1. lsp_symbols(scope="document", filePath="src/index.ts")  → file outline
2. lsp_goto_definition(...)                                 → trace any symbol
3. lsp_find_references(...)                                 → understand usage patterns
```

---

## 3. MCP Ecosystem — When Built-ins Aren't Enough

### What MCPs Are
MCP (Model Context Protocol) servers extend the agent with new tools, resources, and prompts from external systems. Think of them as plugins — but only add them when there's a genuine need a built-in can't meet.

### Evaluation Before Adding Any MCP
Before configuring a new MCP, answer:
1. **Does a built-in tool already solve this?** (Usually yes for file, search, code tasks)
2. **Is it actively maintained?** (Check GitHub: recent commits, open issues, stars)
3. **What's the setup cost?** (API keys? Docker? Local daemon?)
4. **What does it expose?** (Tools vs Resources vs Prompts — tools are callable, resources are readable, prompts are templates)

### MCP Category Reference

| Category | What it gives you | Example servers |
|---|---|---|
| **Databases** | Query your DBs directly | `@modelcontextprotocol/server-postgres`, `mcp-mongodb` |
| **Version Control** | Deep GitHub/GitLab integration (issues, PRs, actions) | `@modelcontextprotocol/server-github` |
| **Web & Search** | Browser automation, scraping, neural search | `@playwright/mcp`, `firecrawl-mcp`, `exa-mcp` |
| **Cloud** | AWS/GCP/Vercel resource management | `aws-mcp`, `vercel-mcp` |
| **Filesystem** | Advanced local file operations beyond built-ins | `@modelcontextprotocol/server-filesystem` |
| **Productivity** | Linear, Notion, Slack, Jira | `linear-mcp`, `notion-mcp` |
| **Monitoring** | Sentry, Datadog, error tracking | `sentry-mcp` |

### MCP Discovery Sources
- `github.com/appcypher/awesome-mcp-servers` — most comprehensive community list
- `github.com/wong2/awesome-mcp-servers` / `mcpservers.org` — curated directory
- `mcp-awesome.com` — verified servers with setup guides

### Using `skill_mcp`
Once an MCP is configured, call it via:
```
skill_mcp(mcp_name="server-name", tool_name="tool-to-call", arguments={...})
```

---

## 4. Tool Selection Decision Tree

```
Need to FIND something?
├── Know the file path → read
├── Know the file pattern → glob
├── Know the text pattern → grep
├── Know the symbol name → lsp_symbols / lsp_goto_definition
└── Know the code structure → ast_grep_search

Need to UNDERSTAND code?
├── What does this symbol do → lsp_goto_definition
├── Who uses this symbol → lsp_find_references
└── What's in this file → lsp_symbols(scope="document")

Need to CHANGE code?
├── Simple text edit → edit
├── Pattern-based transformation → ast_grep_replace (dry-run first)
└── Rename symbol everywhere → lsp_prepare_rename → lsp_rename

Need to VALIDATE changes?
└── lsp_diagnostics (always — before marking any task done)

Need EXTERNAL information?
├── Library docs → context7
├── Code examples → grep_app_searchGitHub
└── Current info / anything else → websearch_web_search_exa
```

---

## 5. Anti-Patterns to Avoid

- Using `bash grep -r` instead of the `grep` tool or `lsp_find_references`
- Using `sed` for renaming symbols — use `lsp_rename` instead
- Grepping for a function name to find its definition — use `lsp_goto_definition`
- Adding an MCP for something built-in tools handle (e.g., MCP for file search)
- Running a full `tsc` or `npm run build` to check for errors — use `lsp_diagnostics`
- Fetching web docs for a library before trying `context7`

# OpenCode Dotfiles

Personal configuration and skill library for [OpenCode](https://opencode.ai) + [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode).

This is the **live** config for `~/.config/opencode/` itself (the directory where opencode reads its global config), tracked as a git repo so you can switch model providers by switching branches.

## Branches

| Branch | Purpose | Models |
|--------|---------|--------|
| `main` | **GitHub Copilot** models (paid, high token budget) | `github-copilot/*` (claude-sonnet-5, gpt-5.6-sol, gpt-5.6-terra, ...) |
| `free` | **Free / open** models (big-pickle, nemotron, ...) — no Copilot budget | `opencode/*-free` |

### Switching providers

```bash
# Use GitHub Copilot models (default)
git -C ~/.config/opencode checkout main

# Use free models (big-pickle, nemotron, etc.)
git -C ~/.config/opencode checkout free
```

Then restart opencode. The `oh-my-openagent.json` and `opencode.json` files are switched wholesale — every agent/category gets a model appropriate to its role from the selected provider.

> Note: This is the **global** switch. You can still override per-project by dropping a
> `.opencode/oh-my-openagent.json` in a specific project (takes precedence over the global one),
> e.g. to force a single repo to use copilot even when globally on `free`.

## Layout

```
~/.config/opencode/
├── opencode.json              # Base OpenCode config (plugins, permissions, providers)
├── oh-my-openagent.json       # oh-my-opencode agent/category model assignments
├── plugins/rtk.ts             # RTK rewrite plugin (token savings)
├── skills/                    # Personal skill library (42 skills)
│   ├── README.md
│   └── <skill-name>/SKILL.md
└── .gitignore                 # Ignores node_modules, caches, backups, secrets
```

**Not tracked** (gitignored): `node_modules/`, `package.json`/`package-lock.json`, `config.json`
(legacy), `*.bak` backups, `plugins/` cache, and local runtime state. Auth tokens live in
`~/.local/share/opencode/` and are **never** committed.

## Setup on a new machine

```bash
# Clone directly into ~/.config/opencode
git clone git@github.com:odedindi/opencode-dotfiles.git ~/.config/opencode
cd ~/.config/opencode

# Install plugin dependencies (oh-my-opencode, copilot-auth are pulled by opencode)
git checkout main        # or `free` for free models
```

oh-my-opencode auto-discovers skills from `~/.config/opencode/skills/*/SKILL.md`.

## Syncing changes

```bash
cd ~/.config/opencode

# After editing a skill or config on the current branch:
git add skills/my-skill/SKILL.md
git commit -m "chore(skills): update my-skill"
git push
```

Because `main` and `free` diverge only in model assignment (the `oh-my-openagent.json`,
`opencode.json`, and plugins), keep other changes (new skills, config tweaks) applied to **both**
branches so they don't drift. After changing `main`, rebase/merge into `free`:

```bash
git checkout free
git merge main --no-edit
```

## Adding a New Skill

```bash
mkdir -p ~/.config/opencode/skills/my-skill
# write SKILL.md
cd ~/.config/opencode
git add skills/my-skill/SKILL.md
git commit -m "feat(skills): add my-skill"
git push
```

Skills are plain markdown. No frontmatter required.

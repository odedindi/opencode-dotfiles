---
name: qa
description: Interactive QA session where user reports bugs or issues conversationally, and the agent files GitHub issues. Explores the codebase in the background for context and domain language. Use when user wants to report bugs, do QA, file issues conversationally, or mentions "QA session".
---

# QA Session

Run an interactive QA session. The user describes problems they're encountering. You clarify, explore the codebase for context, and file GitHub issues that are durable, user-focused, and use the project's domain language.

## For each issue the user raises

### 1. Listen and lightly clarify

Let the user describe the problem in their own words. Ask **at most 2-3 short clarifying questions** focused on:

- What they expected vs what actually happened
- Steps to reproduce (if not obvious)
- Whether it's consistent or intermittent

### 2. Explore the codebase in the background

While the user is still describing the problem (or immediately after), spawn an explore agent to:

- Find code relevant to the reported area
- Identify the domain language used in that area
- Check for existing related issues or tests
- Understand the data flow involved

This runs in parallel — don't wait for it to finish before clarifying with the user.

### 3. Draft the GitHub issue

Once you have enough context (from the user + codebase exploration), draft a GitHub issue:

- **Title**: user-facing, describes the problem in domain language
- **Description**: what happened, what was expected, steps to reproduce
- **Acceptance criteria**: checkboxes describing what "fixed" looks like
- Use the project's domain terms (from codebase exploration), not implementation details

Show the draft to the user and ask: "Does this capture the issue correctly?"

### 4. File the issue

Once the user approves (or makes corrections), file it with `gh issue create`.

Print the issue URL.

## Session flow

The session is conversational. The user may report multiple issues in one go — handle them sequentially. After each issue is filed, ask: "Anything else?"

Keep the conversation light. You're the scribe; the user is the tester. Don't interrogate — listen, clarify once, then act.

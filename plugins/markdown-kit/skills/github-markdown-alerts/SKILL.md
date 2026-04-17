---
name: github-markdown-alerts
description: Use when writing human-facing markdown (README, design docs, PR bodies, Confluence drafts, SKILL.md, CLAUDE.md, etc.) and either (a) the user asks to emphasize / warn / highlight a specific point, or (b) you are about to document a genuinely consequential item (irreversible operation, data loss, security concern, breaking change, known trap). Do NOT use for plan.md / context.md / working logs / code comments.
---

# GitHub Markdown Alerts

## Overview

Apply GitHub's five officially rendered alerts — `[!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]` — with user intent as the top priority and strict minimalism as the default style. The default emphasis tool is `**bold**`. Alerts are a scarce resource.

**Core principle:** An alert is valuable only while it still signals "this is genuinely worth stopping for." Overuse turns alerts into decoration and readers start skipping them.

Reference: <https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts>

## When to Use

**Use when:**
- The user explicitly asks to emphasize, warn, highlight, or draw attention to a specific point.
- You are writing human-facing markdown and the content would cause real harm if skimmed past (irreversible operation, data loss, security exposure, breaking change, known trap, required precondition).

**Do NOT use for:**
- `plan.md` / `context.md` / working logs / internal scratch files (not rendered on GitHub, short-lived).
- Code comments.
- Content that plain `**bold**` would already emphasize adequately.
- "Seems kind of important" information.
- Sections that already contain an alert (don't cluster).

## The Iron Law

**User intent takes precedence. Do not silently insert alerts on your own judgment.**

1. **Explicit user request** → pick the appropriate type and apply it. If the type is genuinely unclear, ask.
2. **Proactive suggestion by Claude** → propose the alert and confirm with the user *before* inserting ("Should I mark this with `[!CAUTION]`?"). Never insert silently.
3. **Everything else** → use `**bold**`, headings, or list structure instead.

## Choosing the Right Type

| Type | Use for | Do NOT use for |
|---|---|---|
| `[!NOTE]` | Skim-readable premise or context that readers must still pick up (e.g., "this command requires VPN access"). | Information that is obvious from the surrounding prose. |
| `[!TIP]` | Optional shortcut or alternative that makes the task easier, but is not required. | A regular step in the main procedure. |
| `[!IMPORTANT]` | Key information the reader must not skip to achieve the goal (e.g., "without this flag all nodes restart"). | Anything that merely *feels* important. |
| `[!WARNING]` | Known traps, bugs, or conditions that cause real harm if ignored (e.g., "this version has bug X"). | Minor inconveniences. |
| `[!CAUTION]` | Destructive or irreversible outcomes of a specific action (e.g., `--force-delete` permanently removes data). | Recoverable failures or reversible operations. |

## Syntax

```markdown
> [!WARNING]
> First line of the body.
> Second line — every line needs the `>` prefix. Lists and code blocks work too.

A blank line ends the alert.
```

- Match the language of the surrounding document (English doc → English body; Japanese doc → Japanese body).
- The keyword (`NOTE` / `TIP` / `IMPORTANT` / `WARNING` / `CAUTION`) must be uppercase, inside `[! ... ]`.
- Every line of the alert, including blank continuation lines inside it, must start with `> `.

## Decision Flow

```
Would a reader who skims past this suffer real consequences?
├─ No   → Use **bold** or plain prose. No alert.
└─ Yes  → Did the user explicitly request an alert here?
         ├─ Yes → Pick the type from the table (ask if truly ambiguous).
         └─ No  → Propose the alert to the user and confirm before inserting.
                  e.g., "Want me to mark this with [!CAUTION]?"
```

## Type-Selection Heuristics

- **Destructive and irreversible → `[!CAUTION]`, no debate.** `purge` / `drop` / `force-push` / `rm -rf` / migration `down` / destructive production operations.
- **Known bug or painful trap → `[!WARNING]`.** "Crashes under this condition." "Broken on version X.y."
- **Key to achieving the goal → `[!IMPORTANT]`.** Skipping it makes the whole procedure fail.
- **Precondition or context → `[!NOTE]`.** "VPN required." "Admin rights needed." "Run X first."
- **Optional shortcut → `[!TIP]`.** Not required, but nice to know.

When multiple types fit, **pick the more severe one** (`[!IMPORTANT]` vs `[!CAUTION]` → `[!CAUTION]`).

## Minimalism (Overuse Prevention)

- Aim for **0–2 alerts per document**. If three feels natural, you are overusing them.
- Do not nest alerts inside alerts.
- Do not stack adjacent alerts (no `[!WARNING]` immediately followed by `[!CAUTION]`). Merge them, or demote one to prose.
- Do not pair a heading (e.g., `## Warnings`) with an alert saying the same thing. Pick one.
- Do not let a full paragraph become the alert body. Alerts are for 1–3 sharp lines.

## Common Mistakes

| Pattern | Problem | Fix |
|---|---|---|
| Wrapping every caution in `[!WARNING]` | Warning fatigue — readers skip them all. | Reserve alerts for real harm; demote the rest to `**bold**`. |
| Using `[!NOTE]` as decoration | `[!NOTE]` becomes a meaningless box. | Return it to plain prose. |
| Using `[!IMPORTANT]` for a destructive operation | The irreversibility doesn't land. | Promote to `[!CAUTION]`. |
| `> [!warning]` (lowercase) | Does not render on GitHub. | Always uppercase: `[!WARNING]`. |
| Missing `>` on a continuation line | Alert breaks mid-paragraph. | Add `>` to every line inside the alert, or close it. |
| Claude silently inserting an alert | Disregards user intent. | Propose first, insert only after confirmation. |

## Red Flags — Stop

If any of these go through your head, stop:

- "Let me emphasize this one too" while adding a third alert → **trim back to 0–2**.
- About to insert an alert without asking → **propose it and wait**.
- "Feels important, so `[!IMPORTANT]`" without consulting the table → **re-check against the type table**.
- A heading and an alert saying the same thing → **delete one**.
- Reaching for `[!CAUTION]` on a reversible operation → **demote to `[!WARNING]` or `**bold**`**.

## Example: Before / After

**Before (baseline — bold-only):**
```markdown
### Cautions

- **This operation cannot be undone.** Confirm before executing.
- **Run `--dry-run` first.**
- **Uncommitted changes will be lost.**
```

**After (minimalist alert applied):**
```markdown
> [!CAUTION]
> This operation cannot be undone. Deleted workspaces — including any uncommitted changes
> inside them — cannot be recovered. Run `--dry-run` first to preview the targets, and
> commit or push anything you want to keep.
```

Three separate `**bold**` lines collapse into a single `[!CAUTION]`. The alert lands on the most severe property (destructive and irreversible), and the `--dry-run` guidance is folded in as its mitigation rather than competing as a second alert.

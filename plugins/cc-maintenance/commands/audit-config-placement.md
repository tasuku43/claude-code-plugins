---
description: Audit CLAUDE.md / rules / skills / commands / agents for responsibility alignment. Also lints skill definition quality.
argument-hint: "[output language, e.g. ja / en]"
---

# audit-config-placement

Audit where Claude Code behavior lives. Produces (a) a placement reassignment plan and (b) a skill-definition lint report.

## Boundaries

- **In scope**: CLAUDE.md, rules files, skills, commands, agents — both global and the 5 most recently used projects. Type-change proposals (skill ⇄ command, rule → hook, skill → agent). Skill-definition quality lint.
- **Out of scope**: `settings.json` / permissions / hook implementation validity → `/audit-settings`. Context-window cost → `/audit-context-cost`.

Hook-placement candidates (rules that should be enforced by a hook) belong **here**, not in `/audit-settings`. `/audit-settings` only validates existing hook implementations; candidate proposal is this command's job.

## Fetch Strategy

Start with the cheapest possible inventory pass. Do NOT read file bodies unless Phase A metadata flags an issue. Report what you skipped.

### Phase A — inventory (always, single call)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/bin/inventory-config.sh
```

Returns JSON:

- `global.claude_md`: `{exists, path, line_count, headings[]}`
- `global.rules`: `[{path, line_count}]`
- `global.skills`: `[{path, name, description, line_count, has_do_not_use_for, reference_mentions}]`
- `global.commands`, `global.agents`: `[{path, name, description, line_count}]`
- `recent_projects`: 5 entries with the same shape for each project's `.claude/` tree

This is the **minimum viable fetch** for each target. Do not expand without a reason.

### Phase B — targeted reads (only on Phase A signals)

| Signal | Then read |
|---|---|
| `claude_md.line_count` > 200 | that CLAUDE.md body |
| A rules file > 150 lines | that rules file body |
| Skill `description` short or vague (< 40 chars, no trigger/non-target) | that SKILL.md body |
| Skill `has_do_not_use_for == false` | that SKILL.md body |
| Skill `line_count` > 250 | that SKILL.md body (candidate for reference extraction, but remember: extraction is only useful if conditional or shared) |
| Two or more skills with overlapping names or description keywords | the SKILL.md bodies of the cluster |
| Command or agent appears to duplicate a skill's responsibility | both files |

### Phase C — deep dive

Reserved for ambiguous or high-impact cases. Ask the user before reading more.

## Output Language

Resolve in this order and stop at the first hit:

1. `$ARGUMENTS` — if the user passed a language (e.g. `ja`, `en`, `日本語`), use it verbatim.
2. `~/.claude/CLAUDE.md` — infer from its written language.
3. Conversation history — infer from the user's recent messages.
4. Best guess from any other available signal (project files, commit messages, etc.). Never hard-fallback to English; pick the most probable language from what you have.

Keep this command file itself in English regardless.

## Analysis

### Placement audit

- **Globally placed, should be project-local** — e.g. stack-specific rules living in `~/.claude/CLAUDE.md`.
- **Project-local, should be global** — universal rules duplicated across projects.
- **Belongs in a hook** — deterministic validations written as prose rules.
- **Belongs in a command** — low-frequency explicit procedures currently structured as a skill.
- **Belongs in a skill** — high-frequency auto-triggered procedures currently described in CLAUDE.md.
- **Belongs in an agent** — heavy investigations currently inlined into a skill's instructions.
- **Stale or duplicated** — same rule in two places, or rule diverged from actual enforcement.

### Skill-definition lint

Limit Phase B reads to skills flagged in Phase A; do not audit every skill.

Check each flagged skill for:

1. **Trigger precision** — does the description make the fire condition concrete, and does it state a non-target?
2. **Inline bloat** — is the body primarily long analysis templates or pattern lists that would be used **only conditionally** from multiple callers? Only then is reference extraction a real win. A single-consumer inline expansion is fine.
3. **Single responsibility** — does one skill secretly cover two independent jobs? If so, split.
4. **Trigger collision** — do multiple skills compete on the same phrase? If so, consolidate or re-scope descriptions.

Future lint dimensions (not applied in this run): command-ification of low-frequency skills, agent-ification of heavy investigators, deterministic content that should be a hook.

## Output Format

```markdown
## Current State
- CLAUDE.md: global N lines (N headings) / per project [path: N lines, ...]
- rules: global N / per project [path: N, ...]
- skills: global N / per project [path: N, ...]
- commands: global N / per project [path: N, ...]
- agents: global N / per project [path: N, ...]

## Intentionally Skipped
- <target or area> — <reason>

## Placement Reassignment
### CLAUDE.md ↔ rules / projects
- <rule> → <from> → <to> → <reason>
### Rule → hook candidates
- <rule> → <event + matcher> → <reason>
### Skill ⇄ command / agent
- <name> → <type change> → <reason>
### Duplicates / stale
- <item> → <resolution>

## Skill Lint
### Trigger precision
- <skill> → <issue> → <proposed description rewrite>
### Inline bloat (extraction viable)
- <skill> → <section> → <conditional/shared reason>
### Split candidates
- <skill> → <two jobs detected> → <proposed split>
### Trigger collision
- <skill A>, <skill B> → <shared phrase> → <resolution>
```

## Placement Decision Reference

| Location | Best for | Not for |
|---|---|---|
| CLAUDE.md | Short persistent rules, policies | Long procedures |
| `.claude/rules/*.md` | Long conditional rules that benefit from file-level organization | Short one-liners |
| `settings.json` | Permissions, display, execution mode | Rules, procedures |
| Hook | Deterministic validation, guards | Decisions requiring judgment |
| Skill | High-frequency, auto-triggered reusable procedures | Low-frequency explicit invocations |
| Command | Low-frequency, explicit invocations | Auto-triggering requirements |
| Agent | Heavy investigation in isolated context | Simple reusable procedures |

## Implementation

Apply user-approved changes. For type conversions (skill → command etc.), move and rewrite the frontmatter; do not leave stub redirects. Emit a short change summary.

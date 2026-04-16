---
description: Audit ~/.claude/settings.json — permissions, hooks, and plugin enablement — and propose fixes.
---

# audit-settings

Audit Claude Code settings and propose concrete, verified improvements.

## Boundaries

- **In scope**: `settings.json` / `settings.local.json`, permissions entries, hook implementation validity, plugin enable/disable decisions.
- **Out of scope**: CLAUDE.md / rules / skills / commands / agents placement → use `/audit-config-placement`. Context-window cost → use `/audit-context-cost`.

## Fetch Strategy

Start with the cheapest possible inventory pass. Do NOT read file bodies unless Phase A metadata indicates an issue. Report what you intentionally skip.

### Phase A — inventory (always, single call)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/bin/inventory-settings.sh
```

Returns JSON:

- `settings_global.permissions`: `{allow, deny, ask}` counts
- `settings_global.hooks`: per-event list with `matcher` and `commands`
- `settings_global.plugins`: `{enabled: [...], disabled: [...]}`
- `hook_scripts`: `[{path, line_count, size_bytes}]` under `~/.claude/hooks/`
- `recent_projects`: 5 most recent, each with `settings_local_exists` and permissions counts

### Phase B — targeted reads (only on Phase A signals)

Read a file body only when one of these fires:

| Signal in Phase A | Then read |
|---|---|
| `hook_scripts[i].line_count` < 5 or > 200 | that hook script body |
| A hook `command` points to a path not in `hook_scripts` | the referenced script |
| A recent project has non-zero `settings_local.permissions` AND overlapping counts with global | that project's `settings.local.json` |
| Any permission audit requires seeing actual entries | `~/.claude/settings.json` body |

### Phase C — deep dive (rare)

Reserved for ambiguous cases. If Phase B still doesn't clarify, ask the user before reading more.

## Output Language

Detect the user's primary language from `~/.claude/CLAUDE.md` (if present) or conversation history. Produce output in that language. Keep this file in English.

## Analysis

### Permissions
- Duplicates across allow / deny / ask.
- Meaningless fragments (partial commands, shell syntax artifacts).
- Dangerous commands missing from deny.
- Drift between global and project `settings.local.json` (same rule in both, or conflicting rules).

### Hooks
- Each registered hook: does its command match an existing script in `hook_scripts`?
- Each script in `hook_scripts`: is it still referenced by settings?
- Size anomalies (too small, too large) — worth reading.
- Missing hook types implied by CLAUDE.md content (delegate that judgment to `/audit-config-placement`; do not propose them here).

### Plugins
- Enabled vs disabled list.
- Per plugin: does the user appear to invoke it regularly? (Use conversation context, not speculation.)
- **Not in scope**: skill-count cost estimation — belongs to `/audit-context-cost`.

## Output Format

```markdown
## Current State
- permissions: allow N / deny N / ask N
- hooks: N total (PreToolUse N / PostToolUse N / SessionStart N / ...)
- hook scripts on disk: N files
- plugins: N enabled / N disabled
- recent projects with settings.local.json: N

## Intentionally Skipped
- <file or area> — <reason>

## Permissions
### Immediate fixes
- <issue> → <fix> → risk: <none/low/medium>
### Recommended additions
- <pattern> → allow | deny | ask → <reason>
### Recommended removals
- <entry> → <reason>

## Hooks
### Script issues
- <path> → <problem> → <fix>
### Dangling references
- <hook registration> → <missing script>
### Unused scripts
- <path> → <proposal: delete / re-register>

## Plugins
### Disable candidates
- <plugin> → <reason>
### Project-scope moves
- <plugin> → <target project> → <reason>
```

## Implementation

Apply user-approved changes:

- Edit `settings.json` with the `Edit` tool to preserve structure.
- New hook scripts: create under `~/.claude/hooks/`, `chmod +x`.
- Project-level diff: place only the difference from global in `settings.local.json`.

Apply all approved changes in one batch, then emit a short change summary.

---
description: Audit ~/.claude/settings.json — permissions, hooks, MCP servers, plugins, and security risks — and propose fixes.
argument-hint: "[output language, e.g. ja / en]"
---

# audit-settings

Audit Claude Code settings and propose concrete, verified improvements. Includes a security lens over permissions, hook scripts, MCP servers, and env.

## Boundaries

- **In scope**: `settings.json` / `settings.local.json`, permissions entries, hook implementation validity, MCP server configuration, plugin enable/disable decisions, and the security risk evaluation of all the above.
- **Out of scope**: CLAUDE.md / rules / skills / commands / agents placement → use `/audit-config-placement`. Context-window cost → use `/audit-context-cost`. Code-change security review → use built-in `/security-review`.

## Fetch Strategy

Start with the cheapest possible inventory pass. Do NOT read file bodies unless Phase A metadata indicates an issue. Report what you intentionally skip.

### Phase A — inventory (always, single call)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/bin/inventory-settings.sh
```

Returns JSON:

- `settings_global.permissions`: `{allow: [...], deny: [...], ask: [...], counts: {allow, deny, ask}}` — full entries plus counts
- `settings_global.hooks`: per-event list with `matcher` and `commands`
- `settings_global.plugins`: `{enabled: [...], disabled: [...]}`
- `settings_global.mcp_servers`: `[{name, type, command, url, args_count, env_keys}]` — values of `env` are NOT emitted, only key names
- `settings_global.env_keys`: top-level env var names (no values)
- `hook_scripts`: `[{path, line_count, size_bytes}]` under `~/.claude/hooks/`
- `recent_projects`: 5 most recent, each with `settings_local_exists` and permissions counts

### Phase B — targeted reads (only on Phase A signals)

Read a file body only when one of these fires:

| Signal in Phase A | Then read |
|---|---|
| `hook_scripts[i].line_count` < 5 or > 200 | that hook script body |
| A hook `command` points to a path not in `hook_scripts` | the referenced script |
| A recent project has non-zero `settings_local.permissions` AND overlapping counts with global | that project's `settings.local.json` |
| A permission entry looks dangerous but ambiguous (wildcards, shell metacharacters) and you cannot judge from Phase A alone | `~/.claude/settings.json` body |
| A hook command string contains `eval`, `curl \| sh`, `wget \| sh`, unquoted `$`, or references external URLs | that hook script body, for security inspection |
| An MCP server points to an unfamiliar `command` / `url` | that server's source (only if locally available — never fetch remote URLs) |

### Phase C — deep dive (rare)

Reserved for ambiguous cases. If Phase B still doesn't clarify, ask the user before reading more.

## Output Language

Resolve in this order and stop at the first hit:

1. `$ARGUMENTS` — if the user passed a language (e.g. `ja`, `en`, `日本語`), use it verbatim.
2. `~/.claude/CLAUDE.md` — infer from its written language.
3. Conversation history — infer from the user's recent messages.
4. Best guess from any other available signal (project files, commit messages, etc.). Never hard-fallback to English; pick the most probable language from what you have.

Keep this command file itself in English regardless.

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

### Security
Apply a security lens across the already-gathered data. Do not re-read files — use Phase A entries plus any Phase B bodies already pulled.

- **Permissions — dangerous allows**: unrestricted shell (`Bash(*)`, `Bash(*:*)`), destructive verbs without path scoping (`Bash(rm *)`, `Bash(rm -rf *)`, `Bash(sudo *)`, `Bash(chmod *)`), arbitrary network fetch (`Bash(curl *)`, `Bash(wget *)`, `WebFetch(*)`), credential-exposing commands (`Bash(cat *.env*)`, `Bash(env)`), git destructive (`Bash(git push --force*)`, `Bash(git reset --hard*)`). Distinguish "risky by design" (user clearly knows) from "accidentally broad".
- **Permissions — deny coverage**: critical deny entries that are missing given the allow set (e.g., allow `Bash(git push *)` without deny for force-push; allow `Bash(*)` without deny for credential reads).
- **Hook scripts — injection risk**: `eval`, unquoted `$VAR` / `$1` in command positions, `curl ... | sh`, `wget ... | sh`, writing to arbitrary paths under `/`, network egress to non-allowlisted hosts. Flag each occurrence with the file path and line.
- **Hook scripts — supply-chain**: scripts that download and execute remote code at hook time.
- **MCP servers — trust**: `command` pointing to a non-absolute path or to `$HOME/.npm-global`-style locations that could be hijacked; `url`-based servers that are not on a trusted domain; `env_keys` that look like production secrets (suggest moving to a secret manager, not hardcoding values).
- **Env**: top-level `env_keys` containing `TOKEN`, `KEY`, `SECRET`, `PASSWORD` — flag for review (the script never reads values, but presence is the signal).
- **Project drift**: `settings.local.json` that relaxes (adds allows that global denies) or contradicts global security posture.

For each finding, assign a severity: **critical** (remote code execution, secret leakage possible), **high** (privilege escalation, destructive default), **medium** (broad allow with no deny counterpart), **low** (hygiene).

## Output Format

```markdown
## Current State
- permissions: allow N / deny N / ask N
- hooks: N total (PreToolUse N / PostToolUse N / SessionStart N / ...)
- hook scripts on disk: N files
- mcp servers: N
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

## Security
### Critical
- <finding> → <where: file:line or settings field> → <fix>
### High
- <finding> → <where> → <fix>
### Medium
- <finding> → <where> → <fix>
### Low
- <finding> → <where> → <fix>
```

## Implementation

Apply user-approved changes:

- Edit `settings.json` with the `Edit` tool to preserve structure.
- New hook scripts: create under `~/.claude/hooks/`, `chmod +x`.
- Project-level diff: place only the difference from global in `settings.local.json`.

Apply all approved changes in one batch, then emit a short change summary.

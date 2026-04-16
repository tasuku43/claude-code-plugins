---
description: Audit context-window efficiency — always-injected system prompt size, investigation noise, and large outputs — and propose ROI-ranked reductions.
argument-hint: "[output language, e.g. ja / en]"
---

# audit-context-cost

Audit what is burning context window. Produces an ROI-ranked list of reductions.

## Boundaries

- **In scope**: always-injected system prompt size (plugin skills, custom skills, MCP server instructions, SessionStart output), investigation noise in session logs, large verbatim outputs, subagent delegation design.
- **Out of scope**: permissions / hook validity → `/audit-settings`. CLAUDE.md / skill placement or definition quality → `/audit-config-placement`.

## Fetch Strategy

Start with metadata only. Do NOT read log bodies, skill bodies, or MCP server bodies in the main context. Report what you skip.

### Phase A — inventory (always, single call)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/bin/inventory-context.sh
```

Returns JSON:

- `enabled_plugins`: `[{name, path, found, skills, commands, agents}]`, where `skills` is `{count, description_bytes_total, top: [{path, description_bytes}]}` (top-5 largest descriptions — these are the always-injected cost per skill)
- `custom`: `{skills_global, commands_global, agents_global}` — `skills_global` has the same `{count, description_bytes_total, top}` shape
- `mcp`: `{servers: [...], count}`
- `session_start_hooks`: list of SessionStart command strings
- `recent_log_metadata`: 5 recent projects, each with top-3 `.jsonl` by size (`{path, size_bytes, mtime_epoch}`)

The `description_bytes_total` is the primary always-injected cost signal. Use it to rank reduction candidates instead of skill counts — 30 short skills can be cheaper than 5 verbose ones.

### Phase B — targeted reads (only on Phase A signals)

| Signal | Then do |
|---|---|
| Any enabled plugin with `found == false` | Investigate — it is enabled but not installed |
| A plugin with large `skills.description_bytes_total` that the user rarely uses (judge from conversation context) | Treat as a disable / project-scope candidate without reading further |
| A single entry in `skills.top[]` has `description_bytes` disproportionate to peers (e.g., >2× the next one) | Read that SKILL.md frontmatter — the description may be bloated and can be trimmed |
| SessionStart hook output is unknown | Run the command(s) once and measure output size |
| MCP `count > 0` | Inspect `settings.json` `mcpServers` entry for server-instruction size |

### Phase C — delegate heavy log analysis

Only when you need concrete context-pressure evidence. Dispatch the log-analyzer agent; do not load log bodies into this context.

```
Agent({
  description: "Sample recent session logs for context-pressure patterns",
  subagent_type: "cc-maintenance:context-log-analyzer",
  prompt: "<pass the recent_log_metadata array from Phase A verbatim; state which patterns you care about>"
})
```

Use the agent's summary in the final report. Do not re-read the logs here.

## Output Language

Resolve in this order and stop at the first hit:

1. `$ARGUMENTS` — if the user passed a language (e.g. `ja`, `en`, `日本語`), use it verbatim.
2. `~/.claude/CLAUDE.md` — infer from its written language.
3. Conversation history — infer from the user's recent messages.
4. Best guess from any other available signal (project files, commit messages, etc.). Never hard-fallback to English; pick the most probable language from what you have.

Keep this command file itself in English regardless.

## Cost Categorization

Classify each always-injected element:

| Element | Counts toward always-injected? |
|---|---|
| Plugin skills (each SKILL.md frontmatter) | yes |
| Custom skills (under `~/.claude/skills/`) | yes |
| Custom commands | no — commands expand only on invocation |
| Plugin commands | no — same reason |
| Agents | no — loaded only when dispatched |
| MCP server instructions | yes |
| MCP deferred tool names | yes (names only, schemas on demand) |
| SessionStart hook output | yes |

## Reduction Methods

| Method | Best for | Savings |
|---|---|---|
| Disable plugin | Rarely-used plugin | Removes all of its injected skill frontmatters |
| Project-scope plugin enable | Plugin useful only in specific projects | Removes injection everywhere else |
| Skill → command conversion | Always-explicit invocation | Removes frontmatter injection; `/audit-config-placement` owns this change |
| Inline → agent delegation | Heavy investigations | Keeps raw data out of main context |
| **Shell-script preprocessing** | Any repeated read where only a fraction of the output is used | Orders-of-magnitude reduction — often the single highest-ROI action |
| Trim SessionStart hook output | Verbose startup hook | Per-session savings |

### When to propose a shell script

Shell-script preprocessing is the most underused reduction method. Propose a concrete script whenever any of these apply:

- The pattern appears **2+ times** across recent logs (from the log-analyzer agent).
- A `Read` / `Bash cat` / `jq` returns a large payload but only a handful of fields are actually used downstream.
- The user or Claude repeatedly does decode → filter → aggregate over the same data source (logs, settings, inventory, metrics).
- An MCP tool response is consistently over-fetched (full issue body where only title+status is needed, etc.).
- A CLI has a `--format json` or equivalent flag whose output still needs post-processing to be useful.

Every proposed script MUST:

- Emit structured output (JSON preferred) to stdout, errors to stderr.
- Return only the fields actually needed for the downstream decision — never the full source.
- Be side-effect-free unless the caller explicitly opts in.
- Accept env-var overrides for tunables (paths, limits) instead of baking in.
- Be under ~150 lines; if larger, split or reconsider the scope.

### Where proposed scripts live

| Scope | Location | Notes |
|---|---|---|
| User-global (cross-project) | `~/.claude/bin/<name>.sh` | Create the directory if missing. `chmod +x`. |
| Plugin-scoped | `<plugin-root>/bin/<name>.sh` | Follow the plugin's existing conventions (see `cc-maintenance/bin/*.sh` for shape). |
| One-off per-project | `<project>/.claude/bin/<name>.sh` | Only when the logic is truly project-specific. |

Do not embed scripts inline in `settings.json` hook commands — keep them as files so they can be diffed, reviewed, and versioned.

## Output Format

```markdown
## Always-Injected Cost
| element | count | description bytes | notes |
|---|---|---|---|
| plugin: <name> | N skills | N bytes | <frequency note> |
| ... | ... | ... | ... |
| custom skills | N | N bytes | |
| MCP deferred tools | N | — | names only |
| SessionStart output | — | <size or "unmeasured"> | |
| **total always-injected** | N | **N bytes** | |

## Intentionally Skipped
- <target or area> — <reason>

## Context Pressure Patterns (from log-analyzer)
### Already mitigated
- <pattern> → <existing mitigation>
### Unmitigated
- <pattern> → <frequency> → <proposed mitigation> → <implementation type: skill / agent / CLI / hook>

## Recommended Actions (ROI-ranked)
1. <action> — est. reduction: N skills / N tokens / N pattern occurrences — effort: low/medium/high
2. ...

## Proposed Scripts
### <script-name>.sh
- **Path**: `~/.claude/bin/<script-name>.sh` (or plugin-scoped path)
- **Purpose**: <what pattern it replaces>
- **Estimated savings**: <tokens per invocation × occurrences>
- **Usage**: `bash ~/.claude/bin/<script-name>.sh [args]`
- **Implementation**:
```bash
#!/usr/bin/env bash
# <purpose in one line>
set -euo pipefail
# ... actual script body, ready to drop in ...
```
```

## Implementation

Apply user-approved changes. Skill → command conversions are delegated to `/audit-config-placement`. Plugin enable/disable edits go through `settings.json`. New agents go under `~/.claude/agents/` or the relevant plugin's `agents/` directory.

For **Proposed Scripts**:
- Create the file at the path specified in the report with the exact content proposed.
- `chmod +x` immediately after creation.
- If the script belongs in `~/.claude/bin/` and that directory does not exist, create it.
- Do not modify `PATH` — invoke by absolute path from downstream callers.
- After creation, verify with a smoke test (`bash <path> --help` or one representative invocation) and report output size vs. the original pattern's size to confirm the reduction.

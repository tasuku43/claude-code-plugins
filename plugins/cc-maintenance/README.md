# cc-maintenance

[日本語 README](./README.ja.md)

Audit and re-design your Claude Code environment. Three commands plus one subagent, each with a narrow responsibility and a metadata-first fetch strategy so audits stay cheap.

## Installation

Add the marketplace once (if you haven't):

```
plugin marketplace add tasuku43/claude-code-plugins
```

Then install this plugin:

```
plugin install cc-maintenance@tasuku43-plugins
```

The `@tasuku43-plugins` suffix disambiguates against any plugin with the same name in other marketplaces.

## Commands

These are commands (not skills) because auditing always happens with explicit user intent — there is no value in auto-triggering.

| Command | Responsibility |
|---|---|
| `/audit-settings` | `settings.json` / `settings.local.json`, permissions, hook implementation validity, MCP servers, plugin enable/disable, and a security lens across all of these (dangerous allows, hook injection, MCP trust, env secrets). |
| `/audit-config-placement` | CLAUDE.md / rules / skills / commands / agents responsibility alignment. Type-change proposals (skill ⇄ command, rule → hook, skill → agent). Skill-definition quality lint. |
| `/audit-context-cost` | Always-injected system prompt size, investigation noise in session logs, large outputs, subagent delegation design. |

Hook-placement candidates (rules that should become hooks) belong to `/audit-config-placement`. `/audit-settings` only validates existing hook implementations.

## Agent

- `cc-maintenance:context-log-analyzer` — samples recent session `.jsonl` logs for context-pressure patterns. Dispatched by `/audit-context-cost`. Keeps raw log bodies inside its isolated context; only a summary returns to the caller.

## Fetch Strategy

Each command follows a three-phase fetch pattern to avoid over-reading:

- **Phase A (always)** — one call to a shell script under `bin/`. Returns structured JSON: file paths, counts, sizes, frontmatter fields, heading lists. No file bodies.
- **Phase B (on signals)** — read specific file bodies only when Phase A flags an issue (size anomaly, overlap, vague description, etc.).
- **Phase C (rare)** — deep dive or subagent dispatch only when Phase B cannot clarify.

Each command reports what it intentionally skipped, so you can see the cost/coverage trade-off.

## Repository Layout

```
cc-maintenance/
  .claude-plugin/plugin.json
  README.md
  bin/
    inventory-settings.sh      # Phase A for /audit-settings
    inventory-config.sh        # Phase A for /audit-config-placement
    inventory-context.sh       # Phase A for /audit-context-cost
  agents/
    context-log-analyzer.md    # Subagent for heavy log sampling
  commands/
    audit-settings.md
    audit-config-placement.md
    audit-context-cost.md
```

The `bin/` scripts emit JSON to stdout. Commands reference them via `${CLAUDE_PLUGIN_ROOT}/bin/<name>.sh`.

## Requirements

- `jq` — required by all three inventory scripts. `brew install jq` on macOS.
- macOS or Linux — scripts use `stat -f` (BSD) with `stat -c` (GNU) fallback.
- Bash 3.2+.

## Output Language

Each command resolves its output language in this order:

1. Command argument (e.g. `/audit-settings ja`) — used verbatim.
2. `~/.claude/CLAUDE.md` — inferred from its written language.
3. Conversation history — inferred from your recent messages.
4. Best guess from any other available signal. There is no hard English fallback.

Command definitions themselves are always written in English.

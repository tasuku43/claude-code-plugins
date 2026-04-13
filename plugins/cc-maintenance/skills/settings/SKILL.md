---
name: settings
description: >
  Audit permissions, hooks, and plugins in settings.json and propose improvements.
  Triggers: "audit settings", "check permissions", "review hooks", "audit plugins".
  Do NOT use for: CLAUDE.md / skill content (use cc-maintenance:skills), context efficiency (use cc-maintenance:context).
---

# CC Audit: Settings

Audit permissions, hooks, and plugins in settings.json and propose improvements.

## Scope

| In scope | Includes |
|----------|----------|
| permissions | Validity of allow / deny / ask entries, duplicates, gaps, stale entries |
| hooks | Verify existing hooks, propose missing hooks |
| plugins | Inventory of enabled plugins, enable/disable recommendations |
| project settings | Overlap between project-specific settings.local.json and global settings |

| Out of scope | Use instead |
|--------------|-------------|
| CLAUDE.md / skill content | `cc-maintenance:skills` |
| Context efficiency / skill count cost analysis | `cc-maintenance:context` |

## Process

Execute entirely in the main context (1M context assumed). Do not use subagents.

### Step 1: Gather Current State

Read the following in order:

1. `~/.claude/settings.json` — full contents
2. `~/.claude/hooks/` — all script contents
3. `~/.claude/CLAUDE.md` — check for rules that should be enforced by hooks
4. `settings.local.json` from the 5 most recently used projects

**Project path decoding:**
Directory names under `~/.claude/projects/` are encoded paths.
`-Users-tasuku43-work-root` → `/Users/tasuku43/work/root` (leading `-` becomes `/`, remaining `-` become `/`).
Append `.claude/settings.local.json` to the decoded path.

### Step 2: Analysis

Analyze from the following perspectives:

#### Permissions
- Duplicates across allow / deny / ask
- Meaningless entries (command fragments, shell syntax artifacts)
- Dangerous commands that should be in deny but aren't
- Permissions duplicated between project settings.local.json and global settings
- Whether aws commands have proper profile separation
- **Quantitative**: count of allow / deny / ask entries, project duplicate count

#### Hooks
- Inventory of existing hooks and each hook's responsibility
- Rules written in CLAUDE.md that are not enforced by hooks
- Review hook script contents for issues

#### Plugins
- All enabled plugins
- All disabled plugins
- Plugins enabled at the project level
- Estimated usage frequency for each plugin (daily use vs. infrequent)
- **Note**: Skill count cost analysis belongs to `cc-maintenance:context`. Focus on enable/disable decisions here

### Step 3: Improvement Proposals

Present proposals in the following structure. Include quantitative evidence for each proposal.

```markdown
## Current State Summary
- permissions: allow N / deny N / ask N
- hooks: N total (PreToolUse N / PostToolUse N / SessionStart N)
- plugins: N enabled / N disabled
- project settings: N projects with custom settings

## Permissions

### Issues to Fix Immediately
- [Issue] → [Fix] → [Risk: none/low/medium]

### Recommended Additions
- [Command pattern] → [allow/deny/ask] → [Reason]

### Recommended Removals
- [Entry] → [Reason]

## Hooks

### Recommended Additions
- [event + matcher] → [What it prevents/automates] → [Priority]

### Improvements to Existing Hooks
- [Hook name] → [Issue] → [Proposed fix]

## Plugins

### Recommended to Disable
- [Plugin name] → [Reason] → [How to re-enable when needed]

### Recommended to Move to Project Scope
- [Plugin name] → [Target project] → [Reason]
```

### Step 4: Implementation

Implement items approved by the user. **Apply all changes at once, then output a change summary.**

## Notes

- When editing settings.json, use the Edit tool for partial edits to avoid breaking existing structure
- Plugin enable/disable is just toggling `true`/`false` in `enabledPlugins`
- When creating new hook scripts, don't forget `chmod +x`
- When creating project-specific settings.local.json, only include the diff from global settings

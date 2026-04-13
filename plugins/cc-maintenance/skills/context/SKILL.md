---
name: context
description: >
  Analyze context efficiency — system prompt bloat, investigation noise, and large outputs consuming context.
  Triggers: "audit context", "context cost", "system prompt size", "context efficiency".
  Do NOT use for: permissions / hooks (use cc-maintenance:settings), CLAUDE.md / skill definitions (use cc-maintenance:skills).
---

# CC Audit: Context

Analyze context efficiency and identify system prompt bloat, investigation noise, and large outputs consuming context.

## Scope

| In scope | Includes |
|----------|----------|
| system prompt | Quantitative evaluation of skill count injected by plugins, MCP instructions, hook output |
| investigation patterns | Identifying investigations running directly in main context |
| large outputs | Command/tool call patterns that consume excessive context |
| subagent usage | Whether existing skills properly delegate to subagents |

| Out of scope | Use instead |
|--------------|-------------|
| Permissions / hooks validity | `cc-maintenance:settings` |
| CLAUDE.md / skill responsibility alignment | `cc-maintenance:skills` |

## Process

### Output Language

Detect the user's primary language from CLAUDE.md, project files, and conversation history during Step 1. Produce all output (analysis, proposals, summaries) in that language. The skill definition itself is in English, but the output must match the user's language.

### Step 1: System Prompt Cost Analysis (Main Context)

Read and quantitatively evaluate the following:

1. **Count skills from enabled plugins**
   - List plugins with `true` in `enabledPlugins` from `~/.claude/settings.json`
   - Find each plugin's skills directory under `~/.claude/plugins/` and count skills
   - Also check project-specific enablement (`settings.local.json` `enabledPlugins`)

2. **Count custom skills**
   - Under `~/.claude/skills/`
   - Under the current project's `.claude/skills/`

3. **Count custom commands**
   - Under `~/.claude/commands/` (commands are not injected into system prompt but expand on invocation)

4. **Check MCP server injections**
   - MCP-related settings in settings.json
   - Count of deferred tools (listed in system-reminder)

5. **Check SessionStart hook output**
   - Read hook scripts to estimate what SessionStart hooks return

**Build a summary table:**

| Element | Skill/Tool Count | Always Injected? |
|---------|-----------------|------------------|
| Plugin: superpowers | N skills | yes |
| ... | ... | ... |
| Custom skills | N | yes |
| Custom commands | N | no (on invocation only) |
| MCP deferred tools | N | names only |
| MCP server instructions | N lines | yes |

### Step 2: Context Pressure Pattern Analysis (Delegate to Subagent)

Session logs can be hundreds of KB to 1MB per file, so delegate this step to a subagent.

```
Agent({
  description: "Analyze context pressure patterns from session logs",
  prompt: `
## Task
Identify patterns that consume excessive context from recent Claude Code session logs.

## Project Path Decoding
Directory names under ~/.claude/projects/ are encoded paths.
Example: -Users-tasuku43-work-root → /Users/tasuku43/work/root
Leading - becomes /, remaining - become /.

## Steps
1. List ~/.claude/projects/ with ls -lt to find the 5 most recently updated projects
2. For each project, sort .jsonl files by size (ls -lS) and identify the top 3
3. For each file:
   - Read the first 100 lines (session start context)
   - Spot-sample 3 sections from the middle (check total line count, read 20 lines at 25%/50%/75% positions)
   - Read the last 50 lines
4. Look for these patterns:
   - Large tool outputs included verbatim (kubectl logs, terraform plan, git diff, helmfile diff, etc.)
   - Chained investigation tool calls (Jira → Confluence → GitHub sequences)
   - Duplicate retrieval of the same information
   - Heavy exploration in main context without subagent delegation
   - Large MCP tool responses

## Output Format

### Session Size Analysis
For each session:
- File path
- Size (KB)
- Estimated topic
- Original project path

### Pressure Patterns
For each pattern:
- Pattern name
- Occurrence count / total samples
- Concrete example (which command/tool output is large, approximate line count)
- Recommended mitigation

### Subagent Delegation Opportunities
- Investigation patterns running in main context that should be delegated to subagents
- Occurrence frequency for each pattern
`
})
```

### Step 3: Improvement Proposals (Main Context)

Integrate quantitative data from Step 1 and subagent results from Step 2.

```markdown
## System Prompt Cost

| Element | Count | Always Injected | Notes |
|---------|-------|----------------|-------|
| Plugin: xxx | N skills | yes | |
| ... | ... | ... | |
| Custom skills | N | yes | |
| Custom commands | N | no | |
| MCP deferred tools | N | names only | |
| Total always injected | N | | |

### Reduction Proposals
- [Target] → [Reduction method] → [Reduction count]

## Context Pressure Patterns

### Already Mitigated
- [Pattern] → [Mitigation (existing skill/hook)]

### Unmitigated
- [Pattern] → [Frequency] → [Recommended mitigation] → [Implementation (Skill / CLI / Subagent)]

## Recommended Actions (by ROI)
1. [Action] — Estimated reduction: N skills / N tokens
2. ...
```

### Step 4: Implementation

Implement items approved by the user.

## Context Reduction Reference

| Method | Best for | Savings |
|--------|----------|---------|
| Disable plugin | Infrequently used plugins | System prompt reduction by skill list size |
| Project-scoped enablement | Plugins used only in specific projects | System prompt reduction in other projects |
| Subagent delegation | Investigations involving large raw data | Raw data stays out of main context |
| CLI preprocessing | Structuring/filtering large outputs | Output size reduced by orders of magnitude |
| fileSuggestion | File exploration | Prevents unnecessary file listing injection |
| Skill → Command conversion | Infrequent skills | Reduces frontmatter loading cost |

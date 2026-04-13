# cc-maintenance

Maintain and optimize your Claude Code environment. Audits your setup, identifies inefficiencies, and proposes actionable improvements.

## Skills

### cc-maintenance:settings

Audits `settings.json` — permissions, hooks, and plugins — and proposes improvements.

- Reviews allow / deny / ask permission entries for duplicates, gaps, and stale rules
- Verifies hook scripts and identifies missing hooks
- Inventories enabled/disabled plugins with usage frequency estimates
- Detects overlap between global and project-specific settings

### cc-maintenance:context-cost

Analyzes context efficiency — system prompt size, investigation noise, and large outputs consuming context window.

- Counts skills injected by each enabled plugin
- Measures MCP tool and server instruction overhead
- Samples session logs to find context pressure patterns (via subagent)
- Proposes reduction actions ranked by ROI

### cc-maintenance:config-placement

Audits CLAUDE.md, rules, skills, and command definitions for responsibility alignment.

- Reviews rule placement across CLAUDE.md, rules files, settings, hooks, skills, and commands
- Identifies duplicates, conflicts, and stale definitions
- Recommends type changes (skill vs. command) and CLAUDE.md vs. rules file placement
- Proposes responsibility reassignment with rationale

## Output Language

Each skill automatically detects the user's primary language from CLAUDE.md and project files, and produces output in that language.

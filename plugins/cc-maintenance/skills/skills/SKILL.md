---
name: skills
description: >
  Audit CLAUDE.md, skills, and command definitions for responsibility alignment and propose reorganization.
  Triggers: "audit skills", "audit commands", "review CLAUDE.md", "responsibility audit".
  Do NOT use for: settings.json / permissions / hooks (use cc-maintenance:settings), context efficiency (use cc-maintenance:context).
---

# CC Audit: Skills

Audit CLAUDE.md, skills, and command definitions for responsibility alignment.

## Scope

| In scope | Includes |
|----------|----------|
| CLAUDE.md | Global + project-level content, validity of responsibility placement |
| Skills | All skills under ~/.claude/skills/ + project .claude/skills/ |
| Commands | All commands under ~/.claude/commands/ + project .claude/commands/ |
| Responsibility separation | Deciding "where should this live?" (CLAUDE.md / settings / hook / skill / command) |

| Out of scope | Use instead |
|--------------|-------------|
| settings.json / permissions / hooks / plugins | `cc-maintenance:settings` |
| Context efficiency | `cc-maintenance:context` |

## Process

Execute entirely in the main context (1M context assumed). Do not use subagents.

### Step 1: Inventory Collection

Read the following in order:

#### CLAUDE.md
1. `~/.claude/CLAUDE.md`
2. CLAUDE.md from the 5 most recently used projects
3. External files referenced from CLAUDE.md

#### Skills
4. All SKILL.md files under `~/.claude/skills/`
5. All SKILL.md files under `.claude/skills/` of the above 5 projects

#### Commands
6. All `.md` files under `~/.claude/commands/` (**exclude `cc-maintenance-*.md` from analysis**)
7. All `.md` files under `.claude/commands/` of the above 5 projects

**Project path decoding:**
Directory names under `~/.claude/projects/` are encoded paths.
`-Users-tasuku43-work-root` → `/Users/tasuku43/work/root` (leading `-` becomes `/`, remaining `-` become `/`).
Append CLAUDE.md, `.claude/skills/`, `.claude/commands/` to the decoded path.

### Step 2: Analysis

Analyze from the following perspectives:

#### CLAUDE.md
- Rules placed globally that are project-specific
- Rules placed in projects that should be global
- Rules that should be enforced by hooks but only exist in CLAUDE.md
- Stale rules (potentially diverged from actual behavior)
- Duplicates (same rule in both global and project CLAUDE.md)
- **Quantitative**: rule count for global, rule count per project

#### Skills / Commands
- Name, description, triggers, and primary function of each skill/command
- Duplicates or conflicts between skills (multiple skills matching the same trigger)
- Description quality (too vague? "Do NOT use for" clearly stated?)
- Overlap with plugin-provided skills (if overriding, is the intent clear?)
- Whether each should be a skill or command:
  - High frequency or auto-triggered → skill
  - Low frequency or explicit invocation → command
- **Quantitative**: skill count, command count, breakdown by project

#### Responsibility Placement
- Items in CLAUDE.md that should be skills (long procedures, judgment-heavy)
- Items in skills that CLAUDE.md alone would suffice (simple rules)
- Items that should be hooks (deterministic validation)
- Skills that should be commands (low frequency, explicit invocation)
- Commands that should be skills (if usage has become frequent)

### Step 3: Improvement Proposals

Present proposals in the following structure:

```markdown
## Current State Summary
- CLAUDE.md: global N rules / per project [project: N rules, ...]
- Skills: global N / per project [project: N, ...]
- Commands: global N / per project [project: N, ...]

## CLAUDE.md

### Rules to Relocate
- [Rule] → [Current location] → [Target location] → [Reason]

### Rules to Remove
- [Rule] → [Reason (stale / duplicate / already enforced by hook)]

### Rules to Add
- [Rule] → [Location] → [Reason]

## Skills / Commands

### Items to Improve
- [Name] → [Issue] → [Proposed improvement]

### Type Changes
- [Name] → [skill → command / command → skill] → [Reason]

### Removal Candidates
- [Name] → [Reason]

### New Creation Candidates
- [Name] → [Type] → [What it does] → [Why this type is optimal]

## Responsibility Reassignment
- [Target] → [From] → [To] → [Reason]
```

### Step 4: Implementation

Implement items approved by the user.

## Placement Decision Reference

| Location | Best for | Not for |
|----------|----------|---------|
| CLAUDE.md | Persistent rules, policies, constraints | Long procedures, judgment-heavy processes |
| settings.json | Permissions, display, execution mode | Rules or procedures |
| Hook | Deterministic validation / guards | Decisions requiring ambiguity resolution |
| Skill | High-frequency, auto-triggered reusable procedures | Low-frequency explicit invocations |
| Command | Low-frequency, explicitly invoked procedures | Auto-triggering requirements |
| CLI tool | Preprocessing large inputs, deterministic transforms | Processes requiring judgment |

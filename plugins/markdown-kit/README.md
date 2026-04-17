# markdown-kit

[日本語 README](./README.ja.md)

Skills for writing human-facing markdown. Currently ships one skill; additional document-writing skills (emphasis conventions, table style, commit-message style, etc.) may land here as the need arises.

## Installation

Add the marketplace once (if you haven't):

```
plugin marketplace add tasuku43/claude-code-plugins
```

Then install this plugin:

```
plugin install markdown-kit@tasuku43-plugins
```

The `@tasuku43-plugins` suffix disambiguates against any plugin with the same name in other marketplaces.

## Skills

| Skill | Triggers on | Responsibility |
|---|---|---|
| `markdown-kit:github-markdown-alerts` | Writing human-facing markdown (README, design docs, PR bodies, Confluence drafts, SKILL.md, CLAUDE.md) when the user asks to emphasize a point, or when Claude is about to document a genuinely consequential item. | Apply GitHub's five rendered alerts (`[!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]`) under a minimalism-first, user-intent-first policy. Explicitly excludes `plan.md` / `context.md` / working logs / code comments. |

### Design notes for `github-markdown-alerts`

- **User intent first.** The skill forbids Claude from silently inserting alerts. When Claude wants to propose one proactively, it must ask and wait for confirmation.
- **Alerts as a scarce resource.** The default emphasis tool stays `**bold**`. The skill targets 0–2 alerts per document.
- **Severity-based type selection.** Destructive / irreversible operations always take `[!CAUTION]`; other types have specific, non-overlapping scopes so the box a reader sees carries real signal.

## Repository Layout

```
markdown-kit/
  .claude-plugin/plugin.json
  README.md
  README.ja.md
  skills/
    github-markdown-alerts/
      SKILL.md
```

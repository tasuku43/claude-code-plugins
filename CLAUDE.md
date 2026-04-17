# claude-code-plugins — contributor notes

This repository hosts the `tasuku43-plugins` marketplace. The notes below apply to every plugin under `plugins/`.

## Language convention

- **Definition files are written in English only.** This covers `SKILL.md`, slash-command definitions under `commands/`, subagent definitions under `agents/`, and any `.claude-plugin/plugin.json` `description` field. Mixed-language definitions are not allowed.
- **User-facing READMEs are bilingual.** Each plugin ships `README.md` (English, primary) and `README.ja.md` (Japanese), with a cross-link in the first line of each file. The marketplace-level `README.md` follows the same policy.
- **Runtime output language is resolved per invocation, not fixed in the definition.** Commands and skills decide their output language from, in order: (1) an explicit argument such as `/audit-settings ja`, (2) `~/.claude/CLAUDE.md`'s written language, (3) the recent conversation history, (4) the best available signal. There is no hard English fallback.

The goal is to keep definitions predictable and searchable in one language while letting user-facing surfaces speak the reader's language.

## Plugin layout

Each plugin under `plugins/<name>/` follows:

```
<name>/
  .claude-plugin/plugin.json
  README.md
  README.ja.md
  commands/        # optional — slash commands
  agents/          # optional — subagents
  skills/          # optional — skills (auto-firing on description match)
  bin/             # optional — shell helpers invoked by the above
```

Register the plugin in `.claude-plugin/marketplace.json` at the repo root.

## When to choose command vs. skill vs. agent

- **Command** (`commands/*.md`) — explicit user intent always required. No value in auto-firing. Example: `/audit-settings`.
- **Skill** (`skills/<name>/SKILL.md`) — should trigger automatically when its description matches the situation. The `description` field is the only trigger surface, so it must be specific and say *when* to use (not *what* it does). Example: `markdown-kit:github-markdown-alerts`.
- **Subagent** (`agents/<name>.md`) — dispatched by a command or skill to isolate heavy context (large log sampling, broad repo scans). Returns only a summary to the caller. Example: `cc-maintenance:context-log-analyzer`.

If a piece of functionality can be enforced deterministically (regex, lint, hook), prefer a hook over documentation.

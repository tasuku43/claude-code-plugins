# cc-maintenance

[English README](./README.md)

Claude Code 環境を監査し、再設計するためのプラグイン。3 つのコマンドと 1 つのサブエージェントで構成され、それぞれ責務を絞り込み、メタデータ優先のフェッチ戦略で監査コストを低く抑えます。

## インストール

マーケットプレイスをまだ追加していなければ先に追加します:

```
plugin marketplace add tasuku43/claude-code-plugins
```

続いて本プラグインをインストール:

```
plugin install cc-maintenance@tasuku43-plugins
```

`@tasuku43-plugins` を付けるのは、他マーケットプレイスに同名プラグインがあった場合の曖昧さを避けるためです。

## コマンド

監査は常にユーザーの明示的な意図で行うものなので、スキルではなくコマンドとして提供しています（自動発火させる価値がないため）。

| コマンド | 責務 |
|---|---|
| `/audit-settings` | `settings.json` / `settings.local.json`、permissions、hook 実装の妥当性、MCP サーバー、プラグインの有効化/無効化、およびこれらに対するセキュリティ観点（危険な allow、hook インジェクション、MCP の信頼性、env 経由のシークレット）。 |
| `/audit-config-placement` | CLAUDE.md / rules / skills / commands / agents の責務整合性。種別変更の提案（skill ⇄ command、rule → hook、skill → agent）。skill 定義の品質 lint。 |
| `/audit-context-cost` | 常時注入されるシステムプロンプトのサイズ、セッションログ中の調査ノイズ、大きな出力、サブエージェント委譲の設計。 |

hook 化候補（hook にすべき rules の検出）は `/audit-config-placement` の責務です。`/audit-settings` は既存 hook 実装の検証のみを行います。

## エージェント

- `cc-maintenance:context-log-analyzer` — 直近のセッション `.jsonl` ログをサンプリングし、コンテキスト圧迫パターンを抽出します。`/audit-context-cost` から起動されます。生ログは隔離コンテキスト内に留め、呼び出し元には要約のみが返ります。

## フェッチ戦略

各コマンドは読み過ぎを避けるため、3 フェーズのフェッチパターンに従います。

- **Phase A (常に実行)** — `bin/` 配下のシェルスクリプトを 1 回呼び出す。構造化 JSON（ファイルパス・件数・サイズ・frontmatter フィールド・見出しリスト）を返す。ファイル本文は読まない。
- **Phase B (シグナル検出時のみ)** — Phase A で問題が示唆された場合（サイズ異常・重複・記述曖昧など）に限り、該当ファイルの本文を読む。
- **Phase C (まれ)** — Phase B でも判断できない場合の深掘り or サブエージェント委譲。

各コマンドは「意図的にスキップした対象」をレポートに含めるので、コスト/カバレッジのトレードオフを可視化できます。

## リポジトリ構成

```
cc-maintenance/
  .claude-plugin/plugin.json
  README.md
  README.ja.md
  bin/
    inventory-settings.sh      # /audit-settings の Phase A
    inventory-config.sh        # /audit-config-placement の Phase A
    inventory-context.sh       # /audit-context-cost の Phase A
  agents/
    context-log-analyzer.md    # ログサンプリング用サブエージェント
  commands/
    audit-settings.md
    audit-config-placement.md
    audit-context-cost.md
```

`bin/` 配下のスクリプトは JSON を stdout に出力します。コマンドからは `${CLAUDE_PLUGIN_ROOT}/bin/<name>.sh` で参照します。

## 必要要件

- `jq` — 3 つの inventory スクリプトすべてで必須。macOS なら `brew install jq`。
- macOS または Linux — スクリプトは `stat -f` (BSD) と `stat -c` (GNU) のフォールバックを使用。
- Bash 3.2+。

## 出力言語

各コマンドは次の順序で出力言語を解決します:

1. コマンド引数（例: `/audit-settings ja`）— そのまま採用。
2. `~/.claude/CLAUDE.md` — 記述言語から推定。
3. 会話履歴 — 直近のユーザーメッセージから推定。
4. その他の利用可能なシグナルからの最尤推定。英語への固定フォールバックはしません。

コマンド定義ファイル自体は常に英語で記述されています。

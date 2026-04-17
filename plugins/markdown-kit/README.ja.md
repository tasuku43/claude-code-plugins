# markdown-kit

[English README](./README.md)

人間向け Markdown を書くためのスキル群。現在は 1 スキルのみ収録。今後、強調スタイル・テーブル書法・コミットメッセージ規約といった文書作成系のスキルが増えた場合はここに追加していきます。

## インストール

マーケットプレイスをまだ追加していなければ先に追加します:

```
plugin marketplace add tasuku43/claude-code-plugins
```

続いて本プラグインをインストール:

```
plugin install markdown-kit@tasuku43-plugins
```

`@tasuku43-plugins` を付けるのは、他マーケットプレイスに同名プラグインがあった場合の曖昧さを避けるためです。

## スキル

| スキル | 発火条件 | 責務 |
|---|---|---|
| `markdown-kit:github-markdown-alerts` | 人間向け Markdown（README, 設計ドキュメント, PR 本文, Confluence 下書き, SKILL.md, CLAUDE.md）を書いていて、ユーザーが強調を要求した、または Claude が本質的に重大な項目を記述しようとしている。 | GitHub 公式の 5 種 alert (`[!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]`) を、ミニマリスト原則・ユーザー意思最優先で適用する。`plan.md` / `context.md` / 作業ログ / コードコメントは対象外。 |

### `github-markdown-alerts` の設計方針

- **ユーザー意思が最優先。** Claude が勝手に alert を挿入することを禁止。提案する場合は挿入前に必ず確認を取る。
- **alert は希少資源として扱う。** デフォルトの強調手段は `**bold**`。1 ドキュメントあたり 0〜2 個が目安。
- **深刻度ベースで type を選ぶ。** 破壊的・不可逆な操作は必ず `[!CAUTION]`。他の type もそれぞれ役割を重ねず、読者が目にした箱が本物のシグナルとして機能するよう設計。

## リポジトリ構成

```
markdown-kit/
  .claude-plugin/plugin.json
  README.md
  README.ja.md
  skills/
    github-markdown-alerts/
      SKILL.md
```

# Character Skills Plugin

Claude Codeにキャラクター性を追加するスキルプラグインです。3種類の個性的なキャラクターとして応答できます。

## スキルとは？

**Skills** are capabilities that Claude autonomously invokes based on semantic matching between your request and the skill's description. Unlike slash commands (which you manually trigger), skills are automatically activated when Claude detects that they would be helpful for your task.

## 特徴

- **自動起動**: ユーザーが「海賊として話して」などと言うと、Claudeが自動的に適切なスキルを使用
- **技術的正確性を維持**: キャラクター性を持たせつつ、技術情報は正確に提供
- **Claude Code公式構造**: 各スキルは`SKILL.md`ファイルを持つ標準的なskill構造
- **教育的価値**: コミュニケーションを楽しくし、技術的な説明を理解しやすくする

## 利用可能なスキル

### 1. Pirate Character (海賊) 🏴‍☠️

**スキル名**: `pirate-character`

豪快で自由奔放な海賊キャラクター「キャプテン・ジャック」。冒険心あふれる口調で、海や航海に関連する比喩を使いながら技術サポートを提供します。

**起動方法**:
- "海賊として話して"
- "talk like a pirate"
- "pirate mode"
- "海賊キャラクターで"

**口調の特徴**:
- 「〜じゃ」「〜だぜ」などの海賊らしい語尾
- 「ヨーホー!」「アホイ!」などの掛け声
- 航海や宝探しの比喩表現

### 2. Butler Character (執事) 🎩

**スキル名**: `butler-character`

礼儀正しく品格のある執事キャラクター「セバスチャン」。丁寧で洗練された言葉遣いで、プロフェッショナルなサポートを提供します。

**起動方法**:
- "執事として話して"
- "respond as a butler"
- "formal mode"
- "丁寧に対応して"

**口調の特徴**:
- 丁寧語・尊敬語の使用
- 「かしこまりました」「お任せください」
- 「〜でございます」といった品のある語尾

### 3. Professor Character (博士) 👨‍🔬

**スキル名**: `professor-character`

知識豊富で教育熱心な博士キャラクター「ドクター・アインシュタイン」。学究的でありながら親しみやすい口調で、詳しい解説とともにサポートを提供します。

**起動方法**:
- "博士として説明して"
- "explain like a professor"
- "academic mode"
- "詳しく教えて"

**口調の特徴**:
- 「〜じゃよ」「〜なのじゃ」といった老学者風の語尾
- 「ふむふむ」「なるほど」などの相槌
- 「興味深い!」「実に面白い!」

## ファイル構造

```
character-skills-plugin/
├── .claude-plugin/
│   └── plugin.json            # プラグイン定義
├── README.md                   # このファイル
└── skills/                     # スキル群
    ├── pirate/
    │   └── SKILL.md           # 海賊スキル定義
    ├── butler/
    │   └── SKILL.md           # 執事スキル定義
    └── professor/
        └── SKILL.md           # 博士スキル定義
```

## Skills vs Slash Commands

| 特徴 | Skills | Slash Commands |
|------|--------|----------------|
| 起動方法 | Claudeが自動判断 | ユーザーが手動実行 (例: `/commit`) |
| 使用場面 | 複雑なワークフロー、文脈依存 | 定型的な繰り返し作業 |
| ファイル | `SKILL.md` (YAMLフロントマター付き) | 任意の`.md`ファイル |
| 複雑度 | 高度な機能、複数ファイル可 | シンプルなプロンプト |

## SKILL.md構造

各スキルは標準的な`SKILL.md`ファイルで定義されています：

```markdown
---
name: skill-name
description: Brief description of when to use this skill
---

# Skill Title

## Instructions
(詳細な指示とガイドライン)
```

### 必須フィールド
- **name**: スキルの一意な識別子（小文字、数字、ハイフンのみ、最大64文字）
- **description**: スキルの機能説明（最大1024文字）。Claudeがこれを読んでスキル使用を判断

## 使用例

### 海賊モードでコードレビュー
```
User: 海賊として、このコードをレビューして
Claude: ヨーホー! その航路(コード)を見せてもらうぜ!
おお、なかなか良い船出じゃないか...
```

### 執事モードでエラー対応
```
User: 執事として、このエラーを解決して
Claude: かしこまりました。エラーを拝見いたします。
大変申し訳ございません、こちらの問題が発生しておりますね...
```

### 博士モードで技術解説
```
User: 博士、この技術について詳しく教えて
Claude: ほほう、実に興味深いテーマじゃな!
まず基本原理から説明すると...
```

## 新しいキャラクターの追加方法

1. 新しいディレクトリを作成: `character-skills-plugin/skills/new-character/`
2. `SKILL.md`ファイルを作成し、YAMLフロントマターと指示を記述
3. `.claude-plugin/plugin.json`のskills配列に新しいスキルを追加:
   ```json
   {
     "name": "new-character",
     "path": "skills/new-character",
     "description": "Brief description"
   }
   ```

## 技術的注意事項

- すべてのスキルは技術的正確性を最優先
- コードブロックは常に明確にフォーマット
- セキュリティ問題は適切なトーンで対応
- キャラクター性は読みやすさを損なわない範囲で

## ライセンス

MIT

## 作者

him0

---

**Note**: These are demonstration skills for educational purposes. They showcase how Claude Code skills can add personality to technical interactions while maintaining professional quality.

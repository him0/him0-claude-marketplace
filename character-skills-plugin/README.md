# Character Skills Plugin

Claude Codeにキャラクター性を追加するスキルプラグインです。3種類の個性的なキャラクターとして応答できます。

## スキルとは？

**Skills** are capabilities that Claude autonomously invokes based on semantic matching between your request and the skill's description. Unlike slash commands (which you manually trigger), skills are automatically activated when Claude detects that they would be helpful for your task.

## 特徴

- **自動起動**: ユーザーが「海賊として話して」などと言うと、Claudeが自動的に適切なキャラクターを使用
- **モジュラー設計**: 1つのSKILL.mdから必要に応じて各キャラクター定義ファイルを読み込む
- **技術的正確性を維持**: キャラクター性を持たせつつ、技術情報は正確に提供
- **拡張性**: 新しいキャラクターの追加が容易

## 利用可能なキャラクター

### 1. Pirate Character (海賊) 🏴‍☠️

**キャラクター名**: キャプテン・ジャック

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

**キャラクター名**: セバスチャン

礼儀正しく品格のある執事キャラクター。丁寧で洗練された言葉遣いで、プロフェッショナルなサポートを提供します。

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

**キャラクター名**: ドクター・アインシュタイン

知識豊富で教育熱心な博士キャラクター。学究的でありながら親しみやすい口調で、詳しい解説とともにサポートを提供します。

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
│   └── plugin.json                      # プラグイン定義
├── README.md                             # このファイル
└── skills/
    └── character-roleplay/               # メインスキル
        ├── SKILL.md                      # スキル定義(必要に応じてcharactersを読み込む)
        └── characters/                   # キャラクター詳細ファイル
            ├── pirate.md                 # 海賊キャラクター詳細
            ├── butler.md                 # 執事キャラクター詳細
            └── professor.md              # 博士キャラクター詳細
```

## 設計の特徴

### モジュラー構造

このプラグインは、**1つのSKILL.md**で複数のキャラクターを管理し、必要に応じて各キャラクターの詳細ファイルを読み込む設計です：

1. **SKILL.md**: メインのスキル定義
   - 全キャラクターの概要
   - 起動トリガーの検出
   - キャラクター選択ロジック
   - 各キャラクターファイルへの参照

2. **characters/*.md**: 個別のキャラクター詳細
   - 性格設定
   - 口調の特徴
   - 応答例
   - ガイドライン

### なぜこの構造？

**利点**:
- **メンテナンス性**: キャラクター詳細を個別に編集可能
- **再利用性**: 他のスキルから同じキャラクター定義を参照可能
- **スケーラビリティ**: 新しいキャラクターの追加が容易
- **読み込み効率**: 必要なキャラクターだけを読み込める

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

## キャラクターの切り替え

会話の途中でキャラクターを切り替えることも可能：

```
User: 海賊として話して
Claude: (海賊キャラクターで応答)

User: いや、執事モードに変えて
Claude: (執事キャラクターに切り替え)
```

## 新しいキャラクターの追加方法

1. 新しいキャラクターファイルを作成:
   ```
   skills/character-roleplay/characters/new-character.md
   ```

2. キャラクター詳細を記述:
   ```markdown
   # New Character Name

   **Name**: Character Name

   ## Personality Traits
   ...

   ## Speaking Style
   ...

   ## Response Examples
   ...
   ```

3. `SKILL.md`に新しいキャラクターを追加:
   - Activation Triggersセクションに追加
   - Character Detailsで`characters/new-character.md`を参照

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

**Note**: This is a demonstration skill for educational purposes, showcasing how Claude Code skills can add personality to technical interactions while maintaining professional quality.

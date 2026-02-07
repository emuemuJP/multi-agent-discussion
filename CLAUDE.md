# Multi-Model Discussion System

> **Version**: 2.4.0
> **Last Updated**: 2026-02-07

## 概要

複数のAIモデル（Claude, Gemini, Codex）がブレインストーミングや討論を行うシステム。
Claude が司会進行を兼務し、Visualizer（Gemini CLI）がリッチ可視化を担当する。
各討論のデータは `discussions/{topic_id}/` に独立して保存される。

## コンパクション復帰時（全エージェント必須）

1. **自分のpane名を確認**: `tmux display-message -p '#{pane_title}'`
2. **対応する instructions を読む**:
   - claude → `instructions/claude.md`
   - gemini → `instructions/gemini.md`
   - codex → `instructions/codex.md`
   - visualizer → `instructions/visualizer.md`
3. **現在の討論を確認**: `ls discussions/`
4. **状態を復元（claude のみ）**: `discussions/{topic_id}/queue/status.yaml` を読む

## システム構成

```
┌──────────────────────────┬──────────────────────────────────┐
│   Pane 0: Claude         │   Pane 2: Gemini                 │
│   司会進行+論理分析       │   創造的発想                      │
│   (Claude Code)          │   (Gemini CLI)                   │
├──────────────────────────┼──────────────────────────────────┤
│   Pane 1: Codex          │   Pane 3: Visualizer             │
│   技術的実装             │   リッチ可視化                    │
│   (Codex CLI)            │   (Gemini CLI)                   │
└──────────────────────────┴──────────────────────────────────┘
```

## 通信プロトコル

- **ポーリング禁止**（API節約）
- 発言内容は YAML ファイルに書く
- 通知は `tmux send-keys` で送る（**best-effort**、到達を前提としない）
- **ターンファイルの存在 = 完了の真の証拠**

### ファイル構成

```
discussions/{topic_id}/
  queue/
    topic.yaml              # 討論トピック（Claude管理）
    consensus.yaml           # 合意状況（Claude管理）
    status.yaml              # 進行状態ステートマシン（Claude管理）
    turns/round_N_*.yaml     # 各ラウンドの発言
  visualizer/
    dashboard.md             # 可視化ダッシュボード
    images/                  # 生成画像
config/settings.yaml         # システム設定
instructions/                # 各エージェントの指示書（詳細はこちら）
```

## 各エージェントの役割

| Pane | エージェント | 役割 | 詳細 |
|------|------------|------|------|
| 0 | Claude | 司会進行 + 論理分析（最後に発言） | `instructions/claude.md` |
| 1 | Codex | 技術的実装、実用性重視 | `instructions/codex.md` |
| 2 | Gemini | 創造的発想、多角的視点 | `instructions/gemini.md` |
| 3 | Visualizer | リッチ可視化（Mermaid + Imagen） | `instructions/visualizer.md` |

### Visualizer の画像生成ルール

- **`final_result.png`**: `scripts/generate_image.py`（Nano Banana Pro API）で生成。**唯一の API 画像生成**
- **`discussion_flow.png`**: Mermaid で生成
- **`.mmd` ファイル**: 各ラウンドで自由に作成OK
- **内容忠実性**: consensus.yaml の結論に基づく内容のみ（議論にない内容の捏造禁止）
- 必須出力は上記 PNG 2枚のみ。追加画像は Claude の明示的依頼時のみ

## 討論フェーズ

1. **Brainstorming** (1R): 各自3案以上の多様なアイデア
2. **Narrowing** (1R): 有望な2-3案に絞り込み
3. **Debate** (3R): 深い議論と比較検討
4. **Synthesis** (2R): 合意形成と結論

## 禁止事項（全エージェント共通）

1. **ポーリング禁止**: 定期的なファイル確認の繰り返し
2. **他者ファイル編集禁止**: 自分の発言ファイル以外を編集しない
3. **指揮系統の遵守**: Claude の司会進行に従う

## send-keys

```bash
tmux send-keys -t discussion:0.X "メッセージ"
sleep 0.5
tmux send-keys -t discussion:0.X Enter
```

| From | To | Target |
|------|----|--------|
| Claude | Gemini | `discussion:0.2` |
| Claude | Codex | `discussion:0.1` |
| Claude | Visualizer | `discussion:0.3` |
| Gemini/Codex | Claude | `discussion:0.0` |

## 討論開始

Claude ペイン（Pane 0）で「〇〇について討論を開始してください」と指示する。
詳細な手順は `instructions/claude.md` を参照。

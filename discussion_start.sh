#!/bin/bash
# ============================================================
# Discussion System Startup Script
# 複数AIモデル討論システム起動スクリプト
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DISCUSSION_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SESSION_NAME="discussion"

# ============================================================
# Functions
# ============================================================

print_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🎭 Multi-Model Discussion System 🎭                       ║
║                                                               ║
║     Claude × Gemini × Codex                                   ║
║     ブレインストーミング・討論プラットフォーム                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_requirements() {
    echo -e "${BLUE}📋 Requirements check...${NC}"

    # Check tmux
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}❌ tmux is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ tmux${NC}"

    # Check claude CLI
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}❌ claude CLI is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ claude CLI${NC}"

    # Check codex CLI
    if ! command -v codex &> /dev/null; then
        echo -e "${RED}❌ codex CLI is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ codex CLI${NC}"

    # Check gemini CLI
    if ! command -v gemini &> /dev/null; then
        echo -e "${RED}❌ gemini CLI is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ gemini CLI${NC}"

    echo ""
}

cleanup_session() {
    echo -e "${YELLOW}🧹 Cleaning up existing session...${NC}"
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    sleep 1
}

init_discussions_dir() {
    echo -e "${YELLOW}📁 Initializing discussions directory...${NC}"

    # Create discussions directory (discussion data is stored per-topic)
    mkdir -p "$DISCUSSION_DIR/discussions"

    echo -e "${GREEN}✓ Discussions directory ready${NC}"
    echo -e "  ${CYAN}討論データは discussions/{topic_id}/ に保存されます${NC}"
    echo -e "  ${CYAN}ディレクトリ作成は Claude（司会進行）が自動で行います${NC}"

    # List existing discussions if any
    if [ -d "$DISCUSSION_DIR/discussions" ] && [ "$(ls -A "$DISCUSSION_DIR/discussions" 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}既存の討論:${NC}"
        for dir in "$DISCUSSION_DIR/discussions"/*/; do
            if [ -d "$dir" ]; then
                topic_name=$(basename "$dir")
                echo -e "    - ${topic_name}"
            fi
        done
    fi
}

create_tmux_session() {
    echo -e "${BLUE}🖥️  Creating tmux session...${NC}"

    # Create new session with first pane (Claude)
    tmux new-session -d -s "$SESSION_NAME" -n "arena" -x 200 -y 50

    # Split into 2x2 grid
    # First split horizontally (left | right)
    tmux split-window -h -t "$SESSION_NAME:0"

    # Split left column vertically (Claude on top, Codex below)
    tmux split-window -v -t "$SESSION_NAME:0.0"

    # Split right column vertically (Gemini on top, Visualizer below)
    tmux split-window -v -t "$SESSION_NAME:0.2"

    # Now we have:
    # Pane 0: Top-left (Claude)
    # Pane 1: Bottom-left (Codex)
    # Pane 2: Top-right (Gemini)
    # Pane 3: Bottom-right (Visualizer)

    # Set pane titles
    tmux select-pane -t "$SESSION_NAME:0.0" -T "claude"
    tmux select-pane -t "$SESSION_NAME:0.1" -T "codex"
    tmux select-pane -t "$SESSION_NAME:0.2" -T "gemini"
    tmux select-pane -t "$SESSION_NAME:0.3" -T "visualizer"

    # Enable pane borders with titles
    tmux set-option -t "$SESSION_NAME" pane-border-status top
    tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "

    echo -e "${GREEN}✓ Tmux session created${NC}"
    echo ""
    echo -e "${CYAN}Layout:${NC}"
    echo "┌──────────────────────┬──────────────────────┐"
    echo "│ Pane 0: Claude       │ Pane 2: Gemini       │"
    echo "│ 🟣 司会進行+論理分析  │ 🟢 創造的発想         │"
    echo "│ (Claude Code)        │ (Gemini CLI)         │"
    echo "├──────────────────────┼──────────────────────┤"
    echo "│ Pane 1: Codex        │ Pane 3: Visualizer   │"
    echo "│ 🟡 技術的実装        │ 🎨 リッチ可視化       │"
    echo "│ (Codex CLI)          │ (Gemini CLI)         │"
    echo "└──────────────────────┴──────────────────────┘"
    echo ""
}

setup_pane_prompts() {
    echo -e "${BLUE}🎨 Setting up pane prompts...${NC}"

    # Claude (Purple)
    tmux send-keys -t "$SESSION_NAME:0.0" "export PS1='\\[\\033[1;35m\\][Claude]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "clear" Enter

    # Gemini (Green)
    tmux send-keys -t "$SESSION_NAME:0.2" "export PS1='\\[\\033[1;32m\\][Gemini]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.2" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.2" "clear" Enter

    # Codex (Yellow)
    tmux send-keys -t "$SESSION_NAME:0.1" "export PS1='\\[\\033[1;33m\\][Codex]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "clear" Enter

    # Visualizer (Cyan)
    tmux send-keys -t "$SESSION_NAME:0.3" "export PS1='\\[\\033[1;36m\\][Visualizer]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "clear" Enter

    sleep 1
    echo -e "${GREEN}✓ Pane prompts configured${NC}"
}

launch_agents() {
    echo -e "${BLUE}🚀 Launching AI agents...${NC}"

    # Launch Claude agent (Claude Code)
    echo -e "  ${PURPLE}Starting Claude (Claude Code)...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "claude --dangerously-skip-permissions" Enter
    sleep 2

    # Launch Codex agent (OpenAI Codex CLI)
    echo -e "  ${YELLOW}Starting Codex (OpenAI Codex CLI)...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.1" "codex --dangerously-bypass-approvals-and-sandbox" Enter
    sleep 2

    # Launch Gemini agent (Google Gemini CLI)
    echo -e "  ${GREEN}Starting Gemini (Google Gemini CLI)...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.2" "gemini -y" Enter
    sleep 2

    # Launch Visualizer agent (Gemini CLI)
    echo -e "  ${CYAN}Starting Visualizer (Gemini CLI)...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.3" "gemini -y" Enter
    sleep 2

    echo -e "${GREEN}✓ All agents launched${NC}"
}

send_instructions() {
    echo -e "${BLUE}📜 Sending instructions to agents...${NC}"

    sleep 3  # Wait for Claude CLI to initialize

    # Send instruction to Claude
    echo -e "  ${PURPLE}Instructing Claude...${NC}"
    CLAUDE_INST=$(cat "$DISCUSSION_DIR/instructions/claude.md" 2>/dev/null || echo "You are Claude, a discussion participant. Read instructions/claude.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.0" "$CLAUDE_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.0" Enter

    # Send instruction to Gemini
    echo -e "  ${GREEN}Instructing Gemini...${NC}"
    GEMINI_INST=$(cat "$DISCUSSION_DIR/instructions/gemini.md" 2>/dev/null || echo "You are Gemini, a discussion participant. Read instructions/gemini.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.2" "$GEMINI_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.2" Enter

    # Send instruction to Codex
    echo -e "  ${YELLOW}Instructing Codex...${NC}"
    CODEX_INST=$(cat "$DISCUSSION_DIR/instructions/codex.md" 2>/dev/null || echo "You are Codex, a discussion participant. Read instructions/codex.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.1" "$CODEX_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.1" Enter

    # Send instruction to Visualizer
    echo -e "  ${CYAN}Instructing Visualizer...${NC}"
    VIS_INST=$(cat "$DISCUSSION_DIR/instructions/visualizer.md" 2>/dev/null || echo "You are the Visualizer. Read instructions/visualizer.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.3" "$VIS_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.3" Enter

    echo -e "${GREEN}✓ Instructions sent${NC}"
}

print_usage() {
    echo -e "${CYAN}"
    cat << 'EOF'

════════════════════════════════════════════════════════════════
                         使い方
════════════════════════════════════════════════════════════════

1. 討論セッションにアタッチ:
   $ tmux attach -t discussion

2. ペイン間移動:
   Ctrl+b → 矢印キー

3. 討論トピックを設定:
   Claudeペイン（左上）で:
   "〇〇について討論を開始してください"

4. セッション終了:
   $ tmux kill-session -t discussion

════════════════════════════════════════════════════════════════
EOF
    echo -e "${NC}"
}

# ============================================================
# Main
# ============================================================

main() {
    print_banner
    check_requirements
    cleanup_session
    init_discussions_dir
    create_tmux_session
    setup_pane_prompts
    launch_agents
    send_instructions
    print_usage

    echo -e "${GREEN}🎉 Discussion system is ready!${NC}"
    echo -e "${YELLOW}Run: tmux attach -t discussion${NC}"
}

main "$@"

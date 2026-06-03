#!/bin/bash
# Launches mock AI tools with proper pseudo-terminals (pty) so the app can detect them.
# Each mock runs in a `script`-allocated pty, simulating real terminal usage.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="/tmp/codexreminder_demo"
mkdir -p "$TMP_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Launching mock AI tools with proper terminals...${NC}"
echo ""

# Use 'script' to allocate a pty for each mock
# This makes lsof show /dev/ttysXXX for stdin, which the app needs

script -q "$TMP_DIR/codex_pty.log" /bin/bash -c "
    exec -a codex-cli bash '$SCRIPT_DIR/mock_codex.sh'
" &
PID1=$!
sleep 1

script -q "$TMP_DIR/claude_pty.log" /bin/bash -c "
    exec -a claude-code bash '$SCRIPT_DIR/mock_claude.sh'
" &
PID2=$!
sleep 1

script -q "$TMP_DIR/qoder_pty.log" /bin/bash -c "
    exec -a qodercli bash '$SCRIPT_DIR/mock_qoder.sh'
" &
PID3=$!
sleep 1

echo -e "${GREEN}Mock processes launched:${NC}"
echo "  Codex  → PID group starting at $PID1"
echo "  Claude → PID group starting at $PID2"
echo "  Qoder  → PID group starting at $PID3"
echo ""
echo "Outputs:"
echo "  $TMP_DIR/codex_pty.log"
echo "  $TMP_DIR/claude_pty.log"
echo "  $TMP_DIR/qoder_pty.log"
echo ""
echo -e "${YELLOW}Check the status bar — you should see the animated indicator!${NC}"
echo ""
echo "Press Enter to kill all mock processes and exit..."
read -r
kill $PID1 $PID2 $PID3 2>/dev/null
rm -rf "$TMP_DIR"
echo "Done."

#!/bin/bash
# Simulates AI coding tool hooks requesting user attention via JSON files.
# This mirrors the hook bridge format consumed by CodexReminder.
#
# Usage: ./simulate_notifications.sh
# The status bar app will detect these within 2 seconds.

NOTIFY_DIR="$HOME/.codexreminder/notifications"
RESPONSE_DIR="$HOME/.codexreminder/responses"
mkdir -p "$NOTIFY_DIR"
mkdir -p "$RESPONSE_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CodexReminder — Notification Simulator           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

NOW=$(date +%s)

# Simulate Codex waiting for approval
cat > "$NOTIFY_DIR/codex_$$_1.json" <<EOF
{
    "id": "codex-$$_1",
    "tool": "Codex",
    "type": "auth",
    "message": "Approve file edit: src/main.swift",
    "log": "Codex proposes editing src/main.swift and tests/MainTests.swift",
    "options": [
        { "id": "approve", "label": "Approve", "value": "approve" },
        { "id": "deny", "label": "Deny", "value": "deny" }
    ],
    "pid": $$,
    "cwd": "$(pwd)",
    "timestamp": $NOW,
    "responsePath": "$RESPONSE_DIR/codex_$$_1.json"
}
EOF
echo -e "  ${GREEN}✓${NC} Codex notification created (auth approval)"

sleep 1

# Simulate Claude Code waiting for permission
cat > "$NOTIFY_DIR/claude_$$_2.json" <<EOF
{
    "id": "claude-$$_2",
    "tool": "Claude Code",
    "type": "auth",
    "message": "Allow bash: npm install express",
    "log": "Claude requests permission to run: npm install express",
    "options": [
        { "id": "allow", "label": "Allow", "value": "allow" },
        { "id": "deny", "label": "Deny", "value": "deny" },
        { "id": "allow_all", "label": "Allow All", "value": "allow_all" }
    ],
    "pid": $$,
    "cwd": "$(pwd)",
    "timestamp": $NOW,
    "responsePath": "$RESPONSE_DIR/claude_$$_2.json"
}
EOF
echo -e "  ${GREEN}✓${NC} Claude Code notification created (permission request)"

sleep 1

# Simulate Qoder waiting for user input
cat > "$NOTIFY_DIR/qoder_$$_3.json" <<EOF
{
    "id": "qoder-$$_3",
    "tool": "Qoder CLI",
    "type": "input",
    "message": "Which approach do you prefer?",
    "log": "Qoder asks which implementation strategy to use",
    "options": [
        { "id": "incremental", "label": "Incremental", "value": "incremental" },
        { "id": "rewrite", "label": "Rewrite", "value": "rewrite" }
    ],
    "pid": $$,
    "cwd": "$(pwd)",
    "timestamp": $NOW,
    "responsePath": "$RESPONSE_DIR/qoder_$$_3.json"
}
EOF
echo -e "  ${GREEN}✓${NC} Qoder CLI notification created (user input needed)"

echo ""
echo -e "${YELLOW}▶ Check the macOS status bar — you should see:${NC}"
echo -e "  • Animated orange dots (pulsing)"
echo -e "  • Badge showing '3' (tools waiting)"
echo -e "  • Click the icon to see all 3 tools listed"
echo -e "  • Touch Bar shows the focused tool, log text, and approval choices"
echo ""
echo "Notifications are in: $NOTIFY_DIR"
echo "Choice responses will be written to: $RESPONSE_DIR"
echo ""
echo -e "Press Enter to clear notifications and exit..."
read -r

rm -f "$NOTIFY_DIR/codex_$$_1.json" "$NOTIFY_DIR/claude_$$_2.json" "$NOTIFY_DIR/qoder_$$_3.json"
rm -f "$RESPONSE_DIR/codex_$$_1.json" "$RESPONSE_DIR/claude_$$_2.json" "$RESPONSE_DIR/qoder_$$_3.json"
echo -e "${GREEN}Notifications cleared. Status bar should return to normal.${NC}"

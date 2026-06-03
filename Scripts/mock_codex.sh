#!/bin/bash
# Simulates Codex CLI waiting for user approval
# Writes output then blocks on stdin read
echo "Analyzing codebase..."
echo "Proposed changes:"
echo "  - Modified src/main.swift (added error handling)"
echo "  - Modified tests/MainTests.swift (added test case)"
echo ""
echo "Do you want to proceed? (y/n)"
# Block waiting for input from stdin (this makes process state S+)
read -r response

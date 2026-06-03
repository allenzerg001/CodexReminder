#!/bin/bash
# Simulates Claude Code waiting for permission
echo "Claude Code v1.2.0"
echo "Working directory: $(pwd)"
echo ""
echo "I'd like to edit the file src/app.ts to fix the null pointer issue."
echo ""
echo "Allow Claude to edit src/app.ts?"
echo "[Allow] [Deny] [Allow All]"
read -r response

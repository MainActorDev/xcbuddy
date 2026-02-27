#!/usr/bin/env bash

set -e

echo "🚀 Building xcbuddy for release..."
swift build -c release

# Ensure target directory exists
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

echo "📦 Installing to $INSTALL_DIR/xcbuddy"
cp .build/release/xcbuddy "$INSTALL_DIR/xcbuddy"

# Re-sign the binary to prevent AMFI/Gatekeeper from killing the process on macOS ARM64
echo "✍️  Signing binary..."
codesign -f -s - "$INSTALL_DIR/xcbuddy"

echo "✅ xcbuddy successfully installed!"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo ""
  echo "⚠️  WARNING: $INSTALL_DIR is not in your \$PATH."
  echo "👉 Add the following line to your ~/.zshrc or ~/.bash_profile:"
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  echo "Then run 'source ~/.zshrc' to apply."
else
  echo "💡 You can now run 'xcbuddy --help' from anywhere."
fi

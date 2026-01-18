#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔨 Building Universal Binary for ime-auto.nvim..."
echo ""

# Build the binary
"$SCRIPT_DIR/build-universal-binary.sh"

echo ""
echo "📝 Preparing to commit..."

# Check if there are changes
cd "$PROJECT_ROOT"
if ! git diff --quiet bin/swift-ime; then
  echo "✅ Binary has changed, adding to git..."
  git add bin/swift-ime

  # Show the diff stats
  echo ""
  echo "Changes:"
  git diff --staged --stat

  echo ""
  echo "Committing..."
  git commit -m "chore: Update precompiled Universal Binary

- Built for macOS (Intel + Apple Silicon)
- Binary info: $(lipo -info bin/swift-ime | cut -d: -f2 | xargs)
- Size: $(ls -lh bin/swift-ime | awk '{print $5}')"

  echo ""
  echo "✅ Binary committed successfully!"
  echo ""
  echo "Next steps:"
  echo "  git push origin <your-branch>"
else
  echo "ℹ️  No changes detected in bin/swift-ime"
  echo "Binary is already up to date."
fi

echo ""
echo "Done! 🎉"

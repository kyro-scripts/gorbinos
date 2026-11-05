#!/bin/bash
# Syntax/type check every GDScript file (autoload identifiers are not
# available in --check-only mode, so those errors are filtered out).
cd "$(dirname "$0")/.."
fail=0
for f in $(find scripts -name "*.gd"); do
  out=$(timeout 60 godot --headless --path . --check-only -s "$f" 2>&1 | grep -E "SCRIPT ERROR" | grep -v -E "Identifier not found: (Audio|Game|Settings)|Failed to compile depended" | head -3)
  if [ -n "$out" ]; then echo "== $f"; echo "$out"; fail=1; fi
done
exit $fail

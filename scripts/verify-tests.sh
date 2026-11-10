#!/usr/bin/env bash
# Run the upstream suites that the Linux patch touches.
#
# usage: ./scripts/verify-tests.sh
#
# These cover the extended target table (desktop-build-paths, package-target),
# the hide-to-tray close path and the tray-gated background notice
# (main-startup), and the tray itself. They fail loudly when a new upstream tag
# moves the code this port patches.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$KIT/src"

cd "$SRC"
pnpm exec vitest run --config vitest.config.ts \
  apps/desktop/tests/main-startup.spec.ts \
  apps/desktop/tests/tray.spec.ts \
  apps/desktop/tests/desktop-build-paths.spec.ts \
  apps/desktop/tests/package-target.spec.ts \
  --reporter=dot

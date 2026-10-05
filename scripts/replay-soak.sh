#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Running the EN/TR immediate replay performance baseline."
bash "$REPO_DIR/scripts/test-swift.sh" --filter ReplayPerformanceTests

#!/bin/bash
set -euo pipefail

# Usage: run-tests.sh <ENV_ALIAS> [TEST_LEVEL]
ENV_ALIAS=$1
# testOptions.testLevel, unless given as the second argument.
TEST_LEVEL="RunLocalTests"
if command -v jq >/dev/null 2>&1 && [ -f ci-config.json ]; then
  TEST_LEVEL=$(jq -r '.testOptions.testLevel // "RunLocalTests"' ci-config.json)
fi
TEST_LEVEL="${2:-$TEST_LEVEL}"
case "$TEST_LEVEL" in
  RunLocalTests|RunAllTestsInOrg) ;;
  *) echo "Unknown testOptions.testLevel '${TEST_LEVEL}'. Use RunLocalTests or RunAllTestsInOrg."; exit 1;;
esac
echo "Running Apex tests in ${ENV_ALIAS} at ${TEST_LEVEL}"
sf apex run test --test-level "$TEST_LEVEL" --result-format junit --output-dir test-results --wait 30 --target-org "$ENV_ALIAS"

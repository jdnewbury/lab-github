#!/bin/bash
set -euo pipefail

# Usage: delta-deploy.sh <ENV_ALIAS> [SOURCE_DIR]
ENV_ALIAS="${1}"
SOURCE_DIR="${2:-force-app}"

TO_SHA=$(git rev-parse HEAD)
DEPLOY_TAG="deployed/${ENV_ALIAS}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "[delta] Source directory '${SOURCE_DIR}' not found. Set deployOptions.sourceDir in ci-config.json."
  exit 1
fi

# ── Options ────────────────────────────────────────────────────────────────────
# APPLY_DELETIONS is deployOptions.destructiveChanges. GATE_ALIAS is
# testOptions.gateAlias: the one environment deployed with local tests.
APPLY_DELETIONS="true"
GATE_ALIAS="SFDD"
if command -v jq >/dev/null 2>&1 && [ -f ci-config.json ]; then
  APPLY_DELETIONS=$(jq -r '.deployOptions.destructiveChanges == true' ci-config.json)
  GATE_ALIAS=$(jq -r '.testOptions.gateAlias // ""' ci-config.json)
fi

# Prints a deletions manifest that deployOptions.destructiveChanges keeps out.
skip_deletions() {
  echo "[delta] deployOptions.destructiveChanges is false, so these deletions are not applied:"
  cat "$1"
  echo "[delta] The deploy tag moves past them. Delete them by hand, or list them in manifests/destructiveChanges.xml and turn the option on."
}

# ── Determine FROM SHA ─────────────────────────────────────────────────────────
# With no tag the org's state is unknown, so the whole source is deployed. A new
# or empty org needs no tag; tag by hand only an org that already matches HEAD.
FULL_DEPLOY="${FULL_DEPLOY:-false}"
if [ "$FULL_DEPLOY" = "true" ]; then
  echo "[delta] FULL_DEPLOY is set. Deploying the whole of ${SOURCE_DIR}"
elif git rev-parse "$DEPLOY_TAG" >/dev/null 2>&1; then
  FROM_SHA=$(git rev-parse "$DEPLOY_TAG")
  echo "[delta] Using last-deployed tag '${DEPLOY_TAG}': ${FROM_SHA}"
else
  echo "[delta] No '${DEPLOY_TAG}' tag. Deploying the whole of ${SOURCE_DIR}"
  FULL_DEPLOY=true
fi

# ── Generate delta package ─────────────────────────────────────────────────────
if [ "$FULL_DEPLOY" = "false" ]; then
  mkdir -p delta
  sf sgd source delta --to "$TO_SHA" --from "$FROM_SHA" --output-dir delta --source-dir "$SOURCE_DIR"

  HAS_CHANGES=false
  if [ -f "delta/package/package.xml" ] && grep -q '<members>' "delta/package/package.xml"; then
    HAS_CHANGES=true
  fi

  DESTR_CHANGES=""
  if [ -f "delta/destructiveChanges/destructiveChanges.xml" ] && grep -q '<members>' "delta/destructiveChanges/destructiveChanges.xml"; then
    DESTR_CHANGES="delta/destructiveChanges/destructiveChanges.xml"
  fi
  if [ -n "$DESTR_CHANGES" ] && [ "$APPLY_DELETIONS" != "true" ]; then
    skip_deletions "$DESTR_CHANGES"
    DESTR_CHANGES=""
  fi

  if [ "$HAS_CHANGES" = "false" ] && [ -z "$DESTR_CHANGES" ]; then
    echo "[delta] No metadata changes detected — skipping deploy"
    exit 0
  fi

  if [ "$HAS_CHANGES" = "true" ]; then
    echo "[delta] Changes to deploy:"
    cat delta/package/package.xml
    MANIFEST="delta/package/package.xml"
  else
    # Deletions only: sfdx-git-delta writes a minimal package.xml beside the
    # destructive manifest for exactly this case.
    echo "[delta] Deletions only:"
    cat "$DESTR_CHANGES"
    MANIFEST="delta/destructiveChanges/package.xml"
  fi
else
  mkdir -p delta
  sf project generate manifest --source-dir "$SOURCE_DIR" --output-dir delta --name full-package.xml
  MANIFEST="delta/full-package.xml"
  if ! grep -q '<members>' "$MANIFEST"; then
    echo "[delta] ${SOURCE_DIR} holds no metadata. Nothing to deploy."
    exit 0
  fi
  echo "[delta] Full deploy of $(grep -c '<members>' "$MANIFEST") components"
  DESTR_CHANGES=""
  if [ -f "manifests/destructiveChanges.xml" ] && grep -q '<members>' "manifests/destructiveChanges.xml"; then
    if [ "$APPLY_DELETIONS" = "true" ]; then
      DESTR_CHANGES="manifests/destructiveChanges.xml"
    else
      skip_deletions "manifests/destructiveChanges.xml"
    fi
  fi
fi

# ── Pre-deploy backup of what the release touches ──────────────────────────────
# Both manifests retrieve into one folder, so a component in both is kept once.
# A component the org does not have yet cannot be retrieved; a failed retrieve is
# a warning, and rollback then says the backup is incomplete.
BACKUP_DIR="backups/${ENV_ALIAS}/$(date +%s)"
mkdir -p "$BACKUP_DIR"
echo "[backup] Backing up what this release touches in ${ENV_ALIAS}..."
for BACKUP_MANIFEST in "$MANIFEST" "$DESTR_CHANGES"; do
  if [ -n "$BACKUP_MANIFEST" ] && grep -q '<members>' "$BACKUP_MANIFEST"; then
    if ! sf project retrieve start --manifest "$BACKUP_MANIFEST" --target-org "$ENV_ALIAS" --output-dir "$BACKUP_DIR/source"; then
      echo "[backup] WARNING: retrieve of ${BACKUP_MANIFEST} failed. The backup may be incomplete."
      touch "$BACKUP_DIR/incomplete"
    fi
  fi
done

# ── Deploy ─────────────────────────────────────────────────────────────────────
echo "[deploy] Deploying ${MANIFEST} to ${ENV_ALIAS}..."
DEPLOY_ARGS=(--manifest "$MANIFEST" --target-org "$ENV_ALIAS")
if [ -n "$DESTR_CHANGES" ]; then
  # --ignore-warnings: deleting a component the org no longer has is a warning,
  # and without the flag it fails the whole deploy.
  DEPLOY_ARGS+=(--post-destructive-changes "$DESTR_CHANGES" --ignore-warnings)
fi
if [ -n "$GATE_ALIAS" ] && [ "$ENV_ALIAS" = "$GATE_ALIAS" ]; then
  # Developer Edition orgs and sandboxes default to NoTestRun. The gated
  # environment fails on a failing test or under 75% coverage, as production would.
  echo "[deploy] ${ENV_ALIAS} is testOptions.gateAlias, so this deploy runs local tests and needs 75% coverage."
  DEPLOY_ARGS+=(--test-level RunLocalTests)
fi
sf project deploy start "${DEPLOY_ARGS[@]}"

# The deployed/<alias> tag is moved by the pipeline, after the tests pass, and
# not here: a release that is rolled back must stay ahead of the tag so the next
# run sends it again.

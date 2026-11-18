#!/bin/bash
set -euo pipefail

ENV_ALIAS=$1
LATEST_BACKUP=$(ls -td backups/$ENV_ALIAS/* 2>/dev/null | head -1 || true)
if [ -z "$LATEST_BACKUP" ] || [ ! -d "$LATEST_BACKUP" ]; then
  echo "No backup was taken, so nothing can be restored."
  exit 1
fi
if [ -f "$LATEST_BACKUP/incomplete" ]; then
  echo "WARNING: this backup is incomplete; see the backup step's warnings."
fi
# The backup holds only what the release touched, as it was in the org. Components
# the release added stay in the org, since rollback never deletes.
if [ -d "$LATEST_BACKUP/source" ] && [ -n "$(find "$LATEST_BACKUP/source" -type f -print -quit)" ]; then
  echo "Rolling back to backup: $LATEST_BACKUP"
  sf project deploy start --source-dir "$LATEST_BACKUP/source" --target-org "$ENV_ALIAS"
else
  echo "None of the components this release touched existed in $ENV_ALIAS before it, so there is nothing to restore."
fi
echo "Components this release added are not removed by rollback."

#!/usr/bin/env bash
# Sync translations from web Client into Flutter assets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_L10N="$(cd "$ROOT/../Client/transaltion" && pwd)"
mkdir -p "$ROOT/assets/l10n"
for lang in en ar fr zh; do
  cp "$CLIENT_L10N/$lang.json" "$ROOT/assets/l10n/$lang.json"
done
echo "Synced l10n to $ROOT/assets/l10n"

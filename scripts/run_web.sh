#!/usr/bin/env bash
# Run Flutter web on a fixed port (see web_dev_config.yaml).
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER_ROOT:-./flutter}/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="flutter"
fi

exec "$FLUTTER" run -d chrome --web-port=8080 --web-hostname=localhost "$@"

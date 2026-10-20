#!/usr/bin/env bash
# Build HR360 Go release files for Android and/or iOS.
#
# Usage:
#   scripts/build.sh                 APK + AAB (Android)
#   scripts/build.sh apk             APK only (install on a phone)
#   scripts/build.sh aab             AAB only (Google Play)
#   scripts/build.sh ios             IPA (App Store / TestFlight; needs Xcode + Apple signing)
#   scripts/build.sh all             APK + AAB + IPA
#
# Options:
#   --bump            raise the version before building: 1.0.6+7 -> 1.0.7+8
#   --api <url>       use another API than .env (e.g. http://192.168.1.10:5001 for a local server)
#   --skip-tests      do not run `flutter test` first
#
# Play / App Store need a higher build number (+N) than the last upload: use --bump.
#
# iOS signing: the app uses NFC tag reading, which needs a paid Apple Developer
# Program team (a free "Personal Team" cannot sign it). Pick that team in Xcode:
# open ios/Runner.xcworkspace -> Runner -> Signing & Capabilities.
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER_ROOT:-./flutter}/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="flutter"
fi

targets=()
bump=false
api=""
run_tests=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    apk|aab|ios) targets+=("$1") ;;
    android) targets+=(apk aab) ;;
    all) targets+=(apk aab ios) ;;
    --bump) bump=true ;;
    --api) api="${2:?--api needs a URL}"; shift ;;
    --skip-tests) run_tests=false ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see scripts/build.sh --help)"; exit 1 ;;
  esac
  shift
done
[[ ${#targets[@]} -eq 0 ]] && targets=(apk aab)

if $bump; then
  current=$(grep -E '^version: ' pubspec.yaml | sed 's/version: //')
  name=${current%+*}
  build=${current#*+}
  IFS=. read -r major minor patch <<<"$name"
  next="$major.$minor.$((patch + 1))+$((build + 1))"
  sed -i '' "s/^version: .*/version: $next/" pubspec.yaml
  echo "Version $current -> $next (remember to commit pubspec.yaml)"
fi

version=$(grep -E '^version: ' pubspec.yaml | sed 's/version: //')
api_from_env=$(grep -E '^API_BASE_URL=' .env 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
echo "Building HR360 Go $version for: ${targets[*]}"
echo "API: ${api:-${api_from_env:-(not set in .env)}}"

define_args=()
[[ -n "$api" ]] && define_args+=("--dart-define=API_BASE_URL=$api")

if $run_tests; then
  "$FLUTTER" test
fi

outputs=()
for t in "${targets[@]}"; do
  case "$t" in
    apk)
      "$FLUTTER" build apk --release "${define_args[@]+"${define_args[@]}"}"
      outputs+=("APK  build/app/outputs/flutter-apk/app-release.apk  (install on a phone)")
      ;;
    aab)
      "$FLUTTER" build appbundle --release "${define_args[@]+"${define_args[@]}"}"
      outputs+=("AAB  build/app/outputs/bundle/release/app-release.aab  (upload to Google Play)")
      ;;
    ios)
      if [[ "$(uname)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null; then
        echo "iOS builds need a Mac with Xcode."; exit 1
      fi
      "$FLUTTER" build ipa --release "${define_args[@]+"${define_args[@]}"}"
      ipa=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)
      outputs+=("IPA  ${ipa:-build/ios/ipa/}  (upload with Transporter or Xcode Organizer)")
      ;;
  esac
done

echo
echo "Done: HR360 Go $version"
for o in "${outputs[@]}"; do echo "  $o"; done

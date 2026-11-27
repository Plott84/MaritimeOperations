#!/bin/sh
# Run MaritimeOperationsTests twice: Norwegian (nb/NO) and US English (en/US).
# A decimal comma in one region must not be the only reason a test fails.
#
# Usage:
#   scripts/test-locales.sh <xcodebuild destination>
# Example:
#   scripts/test-locales.sh 'platform=iOS Simulator,name=iPhone 16'

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: scripts/test-locales.sh <destination>" >&2
  echo "example: scripts/test-locales.sh 'platform=iOS Simulator,name=iPhone 16'" >&2
  exit 2
fi

destination=$1
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

cd "$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)" || exit 1

failed=0

run_one() {
  language=$1
  region=$2
  echo "=== MaritimeOperationsTests ${language}/${region} ==="
  if ! xcodebuild test \
    -project MaritimeOperations.xcodeproj \
    -scheme MaritimeOperations \
    -destination "$destination" \
    -only-testing:MaritimeOperationsTests \
    -testLanguage "$language" \
    -testRegion "$region" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY=-
  then
    echo "FAILED: -testLanguage ${language} -testRegion ${region}" >&2
    failed=1
  fi
}

run_one nb NO
run_one en US
exit "$failed"

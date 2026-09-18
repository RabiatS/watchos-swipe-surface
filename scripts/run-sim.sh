#!/bin/zsh
# Builds Flick for the simulator and installs it on a paired iPhone + Watch
# simulator pair, then launches both. WatchConnectivity works between paired
# simulators, so flicks on the Watch window land on the iPhone window.
#
#   scripts/run-sim.sh            # first active pair
#   scripts/run-sim.sh <pairUDID> # a specific pair from: xcrun simctl list pairs
#   FLICK_SEND=left,left,up,tap scripts/run-sim.sh   # script flicks (debug builds)
set -euo pipefail
cd "$(dirname "$0")/.."

PAIR="${1:-}"
PAIRS_JSON="$(xcrun simctl list pairs -j)"
if [[ -z "$PAIR" ]]; then
  PAIR="$(echo "$PAIRS_JSON" | python3 -c '
import json, sys
pairs = json.load(sys.stdin)["pairs"]
active = [k for k, v in pairs.items() if v.get("state", "").startswith("(active")]
print(active[0] if active else "")')"
fi
if [[ -z "$PAIR" ]]; then
  echo "No active iPhone + Watch simulator pair. Make one in Xcode: Window > Devices and Simulators > Simulators > +, pick a Watch and a paired iPhone." >&2
  exit 1
fi

read PHONE WATCH <<< "$(echo "$PAIRS_JSON" | python3 -c "
import json, sys
p = json.load(sys.stdin)['pairs']['$PAIR']
print(p['phone']['udid'], p['watch']['udid'])")"
echo "pair   $PAIR"
echo "phone  $PHONE"
echo "watch  $WATCH"

xcodebuild -project Flick.xcodeproj -scheme Flick \
  -destination "id=$PHONE" -derivedDataPath DerivedData \
  -quiet build

PRODUCTS="DerivedData/Build/Products/Debug-iphonesimulator"
PHONE_APP="$PRODUCTS/Flick.app"
WATCH_APP="$PHONE_APP/Watch/Flick Watch App.app"

xcrun simctl boot "$PHONE" 2>/dev/null || true
xcrun simctl boot "$WATCH" 2>/dev/null || true
open -a Simulator

xcrun simctl install "$PHONE" "$PHONE_APP"
xcrun simctl install "$WATCH" "$WATCH_APP"
xcrun simctl launch --terminate-running-process "$PHONE" com.rabiats.flick
# --terminate-running-process matters on the Watch: wcd relaunches the app in
# the background within a second of a plain terminate, and a later launch just
# attaches to that process without the environment below.
if [[ -n "${FLICK_SEND:-}" ]]; then
  SIMCTL_CHILD_FLICK_SEND="$FLICK_SEND" xcrun simctl launch --terminate-running-process "$WATCH" com.rabiats.flick.watchkitapp
else
  xcrun simctl launch --terminate-running-process "$WATCH" com.rabiats.flick.watchkitapp
fi
echo "Running. Flick on the Watch window; the iPhone window reacts."
echo "Scripted flicks (debug builds): FLICK_SEND=left,up,tap scripts/run-sim.sh"

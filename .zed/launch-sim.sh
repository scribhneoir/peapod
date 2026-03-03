#!/usr/bin/env bash
set -e

: "${PLAYDATE_SDK_PATH:?PLAYDATE_SDK_PATH is not set}"

PDX="$1"

case "$(uname -s)" in
  Darwin)
    open -a "$PLAYDATE_SDK_PATH/bin/Playdate Simulator.app" "$PDX"
    ;;
  Linux)
    "$PLAYDATE_SDK_PATH/bin/PlaydateSimulator" "$PDX"
    ;;
  *)
    echo "Unsupported platform: $(uname -s)" >&2
    exit 1
    ;;
esac

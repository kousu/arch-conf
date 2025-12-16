#!/bin/bash

monitor-idlehint() {
  # echo idle
  # sleep 12
  # echo idle
  # sleep 5
  # echo unidle
  # sleep 15

  while true; do
    busctl wait \
      /org/freedesktop/login1 org.freedesktop.DBus.Properties PropertiesChanged | \
      awk '$4 ~ /IdleHint/ { if($6 == "true") { print "idle" } else { print "unidle" } }'
  done

}

idle() {
  S=$1; shift
  trap '[ -n "$(jobs -p)" ] && kill $(jobs -p) 2>/dev/null' EXIT
  sleep "$S"
  (set -x; "$@")
}

# Approach:
# - on idle event, start a background job with a timer
#   - on timeout, power-saver
# - on unhidle event, kill all background jobs
#   - that way, if unidle happens before timeout, nothing happened
# Con: it might stack many background jobs uselessly. We're trusting DBUS not to send duplicate events.
#
# A different approach could be:
# - wait for idle event (if other events happen, discard?)
# - wait for either unidle event OR timeout event
#   - if unidle, loop
#   - if timeout, power-saver
monitor-idlehint | (
  trap '[ -n "$(jobs -p)" ] && kill $(jobs -p) 2>/dev/null' EXIT
  while read -r cmd; do
    case $cmd in
      idle)
        echo "idle detected"
        idle $((15 * 60)) powerprofilesctl-respect-holds set power-saver &
        ;;
      unidle)
        echo "unidle detected"
        # user has touched the machine. stop the idle timer before it can react.
        jobs -l
        for j in $(jobs -p); do
          kill -0 "$j" && kill "$j"
        done
        wait $(jobs -p) # collect the exit statuses of the killed jobs; otherwise,
                        # they sit in `jobs` with a "killed" status, and we'll try
                        # to kill them again
        ;;
      *)
        echo "Unrecognized event: {$cmd}" >&2
        exit 1
        ;;
    esac
  done
  wait
  )

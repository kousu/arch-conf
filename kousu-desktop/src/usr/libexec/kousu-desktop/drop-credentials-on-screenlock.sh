#!/bin/bash
# Lock gpg-agent (and hence its keychain, pass(1), and other things built on it)
# on GUI screen lock.


debounce() {
  DEBOUNCE_MS=${1:-500}

  local last_state=""
  local last_time=0

  while read -r state; do
    now=$(date +%s%3N)

    if [[ "$state" == "$last_state" ]] && (( "$now" - "$last_time" < $DEBOUNCE_MS )); then
      continue
    fi

    last_state="$state"
    last_time="$now"

    echo "$state"
  done
}


watch_lock_session() {
  # GNOME and KDE and their ilk also use DBUS and also *respond* to logind's lock signals
  # but they don't *send* those lock signals

  trap '[ -n "$(jobs -p)" ] && kill $(jobs -p)' EXIT

  dbus-monitor --session \
    "type='signal',interface='org.gnome.ScreenSaver',member='ActiveChanged'" \
    "type='signal',interface='org.freedesktop.ScreenSaver',member='ActiveChanged'" \
    "type='signal',interface='org.kde.screensaver',member='ActiveChanged'" \
    "type='signal',interface='org.mate.ScreenSaver',member='ActiveChanged'" \
    "type='signal',interface='org.cinnamon.ScreenSaver',member='ActiveChanged'" 2>/dev/null |
  while read -r line; do
    case "$line" in
      "boolean true")
        echo "lock-session"
        ;;
      # "boolean false")
      #   echo "unlock"
      #   ;;
    esac
  done
}

watch_lock_system() {
  trap '[ -n "$(jobs -p)" ] && kill $(jobs -p)' EXIT
  # logind; used by sway, niri, hyprland, also maybe some tty session managers too? etc;
  #
  # the tail is because there's some stray header lines at boot
  dbus-monitor 2>/dev/null --system \
    "type='signal',interface='org.freedesktop.login1.Session',member='Lock'" |
  grep 'member=Lock' |
  while read -r line; do
    case "$line" in
      *)
        echo "lock-system"
        ;;
    esac
  done
}

watch_lock() {
  trap '[ -n "$(jobs -p)" ] && kill $(jobs -p)' EXIT
  watch_lock_session & watch_lock_system &
  wait
}

. /etc/profile
echo SSH_AUTH_SOCK=$SSH_AUTH_SOCK

watch_lock | debounce | while read state; do
  if [ "$state" != "lock-system" ] && [ "$state" != "lock-session" ]; then continue; fi
  echo "$state: locking credentialss" >&2
  (set -x
  ssh-add -D
  gpg-connect-agent reloadagent /bye
  # secret-tool lock ??
  )
done

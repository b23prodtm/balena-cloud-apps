#!/usr/bin/env bash

### BEGIN INIT INFO
# Provides:          Auto_Reboot
# Required-Start:
# Required-Stop:
# Should-Start:
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Auto Reboot Service
# Description:       Check if the system dpkg need a restart and send corresponding signal.
### END INIT INFO

set -eu

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SVC_NAME=auto_reboot
DAEMON_CF="/etc/$SVC_NAME/$SVC_NAME.conf"
DAEMON_SVC="/usr/lib/systemd/system/$SVC_NAME.service.d/"
# shellcheck disable=SC1091
. /lib/lsb/init-functions

[ -f $DAEMON_CF ] || mkdir -p "$(dirname $DAEMON_CF)"
[ -f $DAEMON_CF ] || touch "$DAEMON_CF"
[ -d $DAEMON_SVC ] || mkdir -p "$DAEMON_SVC"

banner=("" "[services.d] $DAEMON_SVC" ""); log_daemon_msg "%s\n" "${banner[@]}"

DAEMON_CF="$DAEMON_CF $(find "$DAEMON_SVC" -name "*.conf")"
for cnf in $DAEMON_CF; do
  # shellcheck disable=SC1090
  . "$cnf"
done
[ -z "${scriptsd:-}" ] && scriptsd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage=("" \
"Usage: $0 {start|stop|status|restart|install|uninstall}" \
"" \
"Definition: Silently reboot when the system claims:" \
"            *** System restart required ***" \
"")
function install() {
  cp -f "${scriptsd}/$SVC_NAME" "/etc/init.d/$SVC_NAME"
  chmod +x "/etc/init.d/$SVC_NAME"
  systemctl enable "$SVC_NAME"
}
function uninstall() {
  systemctl disable "$SVC_NAME"
  rm -f "/etc/init.d/$SVC_NAME" "$DAEMON_SVC"
}
function start() {
  bash -c "while [ ! -f /run/reboot-required ]; do sleep 30; done; cat /run/reboot-required.dpkgs 2> /dev/null; reboot" &
  echo $! > "/run/$SVC_NAME.pid"
}
function stop() {
  kill "$(cat "/run/$SVC_NAME.pid")"
  rm "/run/$SVC_NAME.pid"
}
function status() {
  if [ -e "/run/$SVC_NAME.pid" ]; then
    echo "$SVC_NAME is running, pid=$(cat "/run/$SVC_NAME.pid")"
  else
    echo "$SVC_NAME is NOT running"
    exit 1
  fi
}
case "$1" in
    start)
       start
       ;;
    stop)
       stop
       ;;
    restart)
       stop
       start
       ;;
    status)
# code to check status of app comes here
# example: status program_name
       status
       ;;
    install)
       install
       ;;
    uninstall)
       uninstall
       ;;
    *)
       printf "%s\n" "${usage[@]}"
       ;;
esac
exit 0

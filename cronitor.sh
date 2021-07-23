#!/bin/bash
#
# This script surrounds the command passed in with start and finish notifications
# to the cronitor monitoring application.
#
# === SETUP
#
# * Make sure the cronitor script is executable.
#
#   chmod +x cronitor
#
# === USAGE
#
# see usage() function below
#
#
# === EXAMPLE
#
# CRONITOR_ID=83a8d6c0c103012efde3lk8092kasdf6 /path/to/cronitor 'ls -l | grep foo | cut -f 3 -d " "'
#
# If invoking using cron, your crontab entry may look something like
#
# * * * * * CRONITOR_ID=83a8d6c0 /path/to/cronitor 'ls -l | grep couch | cut -f 3 -d " "'
#
#
# === DEPENDENCIES
#
# * curl
# * http://cronitor.link
#

usage() {
  cat <<EOF
  $0 [-a][-s][-S] [-i cronitor_id] [-n] [-p] [-t 8] [-e] [-o]
  echo "Usage: CRONITOR_ID=<your cronitor id> cronitor [-...] '<command>'"
           or: cronitor -i <your cronitor id> [-...] 'command'
           -a: auth key to send for all monitor actions
           -s: suppresses output to logger command
           -S: suppresses stdout from command
           -p: disable ssl in favor of plain-text
           -e: do not sleep a few random seconds at start, reduce spikes locally and at Cronitor
           -o: only try curl commands once, even on retryable failures (6, 7, 28, 35), default 3 times
           -t: curl timeout in seconds; default 10
EOF
  exit 1
}

proto=https
timeout=10
sleep=$[ ( $RANDOM % 10 )  + 1 ]
curlcount=3

while getopts ":i:sSpt:eoa:" opt; do
  case $opt in
    i)
      id=$OPTARG
      ;;
    a)
      auth=$OPTARG
      ;;
    s)
      silentlog=1
      ;;
    S)
      silentstdout=1
      ;;
    p)
      proto=http
      ;;
    e)
      sleep=0
      ;;
    o)
      curlcount=1
      ;;
    t)
      timeout=$OPTARG
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
    \?)
      usage
      ;;
  esac
done
shift $(($OPTIND-1))

[ -n "$id" ] && CRONITOR_ID=$id
[ -z "$CRONITOR_ID" ] && usage
[ -n "$auth" ] && auth_arg="auth_key=$auth"

join() {
  local IFS="$1"
  shift
  echo "$*"
}
urlencode() {
  echo "$*" | sed 's/ /%20/g' | sed 's/&/%26/g'
  return 0
}
callcronitor() {
  local mode=${1:-run}
  shift
  local stdout="msg=$(urlencode $*)"
  local pingqs=$(join "&" ${auth_arg} ${stdout})
  local proto=$'\nHost: cronitor.link\n'
  while [ $((curlcount--)) -gt 0 ]; do
    echo "GET /$CRONITOR_ID/$mode?$pingqs HTTP/1.1$proto" | openssl s_client -connect cronitor.link:443
    local e=$?
    [ $e -eq 6 ] && continue
    [ $e -eq 7 ] && continue
    [ $e -eq 28 ] && continue
    [ $e -eq 35 ] && continue
    break
  done
  return $e
}

# sleep skew
# sleep $sleep

# begin
callcronitor
time1=$(date +%s)

cmd="$@"
output=$(bash -c "$@")
E=$?

time2=$(date +%s)
timef=$(($time2 - $time1))

if [ $E -ne 0 ]; then
  mode="fail"
fi

callcronitor ${mode:-complete} ${output}

if [ -z "$silentlog" ]; then
  logger -t cronitor "TaskID=$CRONITOR_ID, ExitStatus=$E, ElapsedTimeMS=$timef, Command=$cmd"
fi

if [ -z "$silentstdout" ]; then
  echo -n "${output}"
fi

exit $E

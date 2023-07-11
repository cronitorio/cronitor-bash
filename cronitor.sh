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
           -E: Environment flag to pass to Cronitor
EOF
  exit 1
}

proto=https
timeout=10
sleep=$[ ( $RANDOM % 10 )  + 1 ]
curlcount=3

while getopts ":i:sSpt:eoa:E:" opt; do
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
    E)
      environment=$OPTARG
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
  data="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$*" "")"
  echo "${data##/?}"
  return 0
}
callcronitor() {
  local mode=${1:-run}
  if [ -n "$environment" ]; then
    local envstr="env=$environment"
  fi
  if [ "$mode" == "fail" -a -n "$2" ]; then
    shift
    local failstr="msg=$(urlencode $*)"
  fi

  local pingqs=$(join "&" ${auth_arg} ${envstr} ${failstr})

  while [ $((curlcount--)) -gt 0 ]; do
    local url=cronitor.link/$CRONITOR_ID/$mode?$pingqs
    url=${url:0:553}
    curl -m$timeout -s --insecure $proto://$url
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
sleep $sleep

# begin
callcronitor
time1=$(date +%s%3N)

cmd="$@"
output=$(bash -c "$@")
E=$?

time2=$(date +%s%3N)
timef=$(($time2 - $time1))

# does this task use the retry wrapper?
retry=$(echo $cmd | grep -o retry.sh)

if [ $E -ne 0 ]; then
  mode="fail"
  fail_str="$output"
fi

callcronitor ${mode:-complete} ${fail_str}

if [ -z "$silentlog" ]; then
  logger -t cronitor "TaskID=$CRONITOR_ID, ExitStatus=$E, ElapsedTimeMS=$timef, Command=$cmd"
fi

if [ -z "$silentstdout" ]; then
  echo -n "${output}"
fi

exit $E

# Cronitor Ping API Client

Cronitor is a service for heartbeat-style monitoring of anything that can send an HTTP request. It's particularly well suited for monitoring cron jobs, Jenkins jobs, or any other scheduled task.

This bash script provides a simple abstraction for the pinging of a Cronitor monitor. For a better understanding of the API this library talks to, please see our [Ping API docs](https://cronitor.io/docs/ping-api). For a general introduction to Cronitor please read [How Cronitor Works](https://cronitor.io/docs/how-cronitor-works).

## Setup
Download cronitor.sh, add it to your PATH, and make sure that it is executable (`chmod +x cronitor`)

## Usage
```
Usage: CRONITOR_ID=<unique monitor id> cronitor [-...] '<command>'"
           or: cronitor -i <your cronitor id> [-...] 'command'
           -a: auth key to send for all monitor actions
           -s: suppresses output to logger command
           -S: suppresses stdout from command
           -p: disable ssl in favor of plain-text
           -e: do not sleep a few random seconds at start, reduce spikes locally and at Cronitor
           -o: only try curl commands once, even on retryable failures (6, 7, 28, 35), default 3 times
           -t: curl timeout in seconds; default 10
```

## Examples

`CRONITOR_ID=83a8d6c0 cronitor /path/to/task.sh`

If invoking using cron, your crontab entry may look something like

```* * * * * CRONITOR_ID=83a8d6c0 cronitor /path/to/task.sh```


## Dependencies
* curl
* https://cronitor.io

## Authors
* [@erchn](https://github.com/erchn)
* [@asheetz2000](https://github.com/asheetz2000)


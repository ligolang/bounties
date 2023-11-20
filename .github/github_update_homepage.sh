#!/usr/bin/env bash

set -euET -o pipefail

echo "Hashing repository contents with IPFS..."

h="$(result/www/ipfs-add.sh)"

echo "After pinning, the new homepage URL will be: https://$h.ipfs.dweb.link/"

if test -n "${IPFS_REMOTE_API_ENDPOINT:-}" && test -n "${IPFS_REMOTE_TOKEN:-}" && test -n "${IPFS_SWARM_CONNECT_TO:-}"; then
  # Wait for IPFS daemon to be ready
  echo 'Starting IPFS daemon...'
  tail -F /tmp/ipfs-daemon.logs -n +1 & pid=$!
  ipfs daemon >/tmp/ipfs-daemon.logs 2>&1 &
  while ! grep 'Daemon is ready' /tmp/ipfs-daemon.logs; do sleep 1; date; done
  echo 'IPFS daemon started, killing log tail...'
  kill "$pid"
  echo 'log tail killed'

  printf %s\\n "$IPFS_SWARM_CONNECT_TO" | (i=1; while read multiaddr; do
    echo "Connecting to IPFS node $i..."
    (
      ipfs swarm connect "$multiaddr" &
    ) > /dev/null 2>&1
    i=$((i+1))
  done)
  sleep 10

  printf %s\\n "$IPFS_REMOTE_API_ENDPOINT" | (i=1; while read api_endpoint; do
    # Pin this hash
    echo "Adding remote pinning service $i..."
    (
      ipfs pin remote service add my-remote-pin-"$i" "$api_endpoint" "$(printf %s\\n "$IPFS_REMOTE_TOKEN" | tail -n +"$i" | head -n 1)"
    ) > /dev/null 2>&1

    echo "Pinning $h on the remote service $i..."
    (
      if ipfs pin remote add --service=my-remote-pin-"$i" --name="site-bounties-$(TZ=UTC git log -1 --format=%cd --date=iso-strict-local HEAD)-$GITHUB_SHA" "$h"; then
        echo $? > ipfs-pin-remote-add-exitcode
      else
        echo $? > ipfs-pin-remote-add-exitcode
      fi
    ) > /dev/null 2>&1
    echo "Finished pinning $h on the remote service $i, exitcode=$(cat ipfs-pin-remote-add-exitcode)"
    i=$((i+1))
  done)
fi

# Update Homepage URL on GitHub
curl -L \
  -X PATCH \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $API_TOKEN_FOR_UPDATE_HOMEPAGE"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/LigoSuzanneSoy/bounties \
  -d '{"name":"bounties", "homepage":"https://dweb.link/ipfs/'"$h"'"}' > /dev/null

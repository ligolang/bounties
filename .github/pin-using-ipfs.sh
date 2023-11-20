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
    echo "Extracting token $i from environment..."
    token="$( (printf %s\\n "$IPFS_REMOTE_TOKEN" | tail -n +"$i" | head -n 1) 2>/dev/null )"
    #(printf %s "$token" | sha256sum | sha256sum | sha256sum) 2>/dev/null # for debugging without leaking the token
    # Pin this hash
    echo "Adding remote pinning service $i..."
    (
      ipfs pin remote service add my-remote-pin-"$i" "$api_endpoint" "$token"
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

# warm up cache, twice (a few files in the first attempt would likely fail as the DHT propagation is not instant)
for i in `seq 2`; do
  ipfs add --progress=false --ignore-rules-path "result/www/.ipfsignore" --pin=false --hidden -r result/www \
  | cut -d ' ' -f 3- \
  | sed -e 's~^www/*~~' \
  | while read f; do
    printf "Warming up Cloudflare cache for $f (attempt $i)..."
    wget -O- "https://cloudflare-ipfs.com/ipfs/$h/$f" > /dev/null || true
    printf "Warming up dweb.link cache for $f (attempt $i)..."
    wget -O- "https://$h.ipfs.dweb.link/$f" > /dev/null || true
    printf "Warming up pinata cache for $f (attempt $i)..."
    wget -O- "https://https://gateway.pinata.cloud/ipfs/$h/$f" > /dev/null || true
  done
done

# LIGO bounties website

## Build && serve

    git add .
    nix build && result/www/ipfs-add.sh

Congratulations, the website is already deployed and served by your local IPFS node, and therefore accessible worldwide. To view it:

## Test (e.g. using brave browser)

    brave $(cat result/ipfs.url)

## Deploy to GitHub pages and a public pin service

    git commit && git push
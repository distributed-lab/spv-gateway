#!/bin/bash

FIRST_BTC_NODE=bitcoind
SECOND_BTC_NODE=bitcoind2
P2P_PORT=18444
FAUCET_ADDRESS=bcrt1quzg7564wdtd2a28wp4fndtckjky7pnycywqdn6
START_TIME=1600000000

BLOCKS_INTERVAL=540

docker exec $FIRST_BTC_NODE /bin/sh -c "bitcoin-cli setmocktime $START_TIME"
docker exec $SECOND_BTC_NODE /bin/sh -c "bitcoin-cli setmocktime $START_TIME"

for i in {1..15}; do
    docker exec $FIRST_BTC_NODE /bin/sh -c "bitcoin-cli setmocktime $(($START_TIME + $BLOCKS_INTERVAL * i))"
    docker exec $SECOND_BTC_NODE /bin/sh -c "bitcoin-cli setmocktime $(($START_TIME + $BLOCKS_INTERVAL * i))"
    docker exec $SECOND_BTC_NODE /bin/sh -c "bitcoin-cli generatetoaddress 1 $FAUCET_ADDRESS"
done

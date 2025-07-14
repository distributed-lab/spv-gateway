#!/bin/bash

FIRST_BTC_NODE=bitcoind
SECOND_BTC_NODE=bitcoind2
P2P_PORT=18444
FAUCET_ADDRESS=bcrt1quzg7564wdtd2a28wp4fndtckjky7pnycywqdn6

START_TIME=1600000000
CURRENT_BLOCK_HEIGHT=14
BLOCKS_INTERVAL=540

CURRENT_TIME=$(($START_TIME + $CURRENT_BLOCK_HEIGHT * $BLOCKS_INTERVAL - 100))

docker stop $FIRST_BTC_NODE

for i in {1..3}; do
    docker exec $SECOND_BTC_NODE /bin/sh -c "bitcoin-cli setmocktime $(($CURRENT_TIME + $BLOCKS_INTERVAL * i))"
    docker exec $SECOND_BTC_NODE /bin/sh -c "bitcoin-cli generatetoaddress 1 $FAUCET_ADDRESS"
done

sleep 5

docker start $FIRST_BTC_NODE

sleep 5

for i in {1..6}; do
    docker exec $FIRST_BTC_NODE /bin/sh -c "bitcoin-cli setmocktime $(($CURRENT_TIME + $BLOCKS_INTERVAL * i + 1))"
    docker exec $FIRST_BTC_NODE /bin/sh -c "bitcoin-cli generatetoaddress 1 $FAUCET_ADDRESS"
done
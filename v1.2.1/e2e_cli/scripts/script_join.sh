#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# join通道时使用
echo
echo " ____    _____      _      ____    _____           _____   ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|         | ____| |___ \  | ____|"
echo "\___ \    | |     / _ \   | |_) |   | |    _____  |  _|     __) | |  _|  "
echo " ___) |   | |    / ___ \  |  _ <    | |   |_____| | |___   / __/  | |___ "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|           |_____| |_____| |_____|"
echo

CHANNEL_NAME="$1"
CHAINCODE_NAME="$2"
: ${CHANNEL_NAME:="bgihealth"}
: ${CHAINCODE_NAME:="token_bgihealth"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5

source ./scripts/funcs.sh $CHANNEL_NAME $CHAINCODE_NAME

#zht join
JOIN_PEER=(16 17 18 19)


### Create channel
#echo "Creating channel..."
#createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel


### Install chaincode on Peer3/Org2
#echo "Installing chaincode on org2/peer3..."
for ch in ${JOIN_PEER[@]}; do
	installChaincode $ch
done

##Query on chaincode on Peer3/Org2, check if the result is 90
#echo "Querying chaincode on org2/peer3..."
chaincodeQuery ${JOIN_PEER[0]} 90

echo
echo "===================== All GOOD, End-2-End execution completed ===================== "
echo

echo
echo " _____   _   _   ____            _____   ____    _____ "
echo "| ____| | \ | | |  _ \          | ____| |___ \  | ____|"
echo "|  _|   |  \| | | | | |  _____  |  _|     __) | |  _|  "
echo "| |___  | |\  | | |_| | |_____| | |___   / __/  | |___ "
echo "|_____| |_| \_| |____/          |_____| |_____| |_____|"
echo

exit 0

#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# 
# 4个peer整体初始化时启动
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
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bgiblockchain.com/orderers/orderer0.bgiblockchain.com/msp/tlscacerts/tlsca.bgiblockchain.com-cert.pem


source ./scripts/funcs.sh $CHANNEL_NAME $CHAINCODE_NAME
JOIN_PEER=(0 1 2 3)

# waiting
sleeptime=30
sleepinterval=3
while [ $sleeptime -gt 0 ]
do
	echo to wait $sleeptime seconds
	sleep $sleepinterval
	sleeptime=$[ sleeptime-sleepinterval ]
done

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 0
echo "Updating anchor peers for org2..."
#updateAnchorPeers 2

## Install chaincode on Peer0/Health and Peer2/Org2
echo "Installing chaincode on org1/peer0..."
for ch in ${JOIN_PEER[@]}; do
	installChaincode $ch
done

#Instantiate chaincode on Peer2/Org2
echo "Instantiating chaincode on org2/peer2..."
instantiateChaincode 2

#Query on chaincode on Peer0/Health
echo "Querying chaincode on org1/peer0..."
chaincodeQuery 0 100

#Invoke on chaincode on Peer0/Health
echo "Sending invoke transaction on org1/peer0..."
chaincodeInvoke 0

#Query on chaincode on Peer3/Org2, check if the result is 90
echo "Querying chaincode on org2/peer3..."
chaincodeQuery 2 90

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

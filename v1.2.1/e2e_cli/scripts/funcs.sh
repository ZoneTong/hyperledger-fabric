#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

CHANNEL_NAME="$1"
CHAINCODE_NAME="$2"
: ${CHANNEL_NAME:="bgihealth"}
: ${CHAINCODE_NAME:="token_bgihealth"}
: ${TIMEOUT:="60"}
: ${ORDERER:="orderer0.bgiblockchain.com"}
: ${JOIN_PEER:= 0 1 2 3 4 5 6 7 8 9 }
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bgiblockchain.com/orderers/${ORDERER}/msp/tlscacerts/tlsca.bgiblockchain.com-cert.pem
# ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bgiblockchain.com/tlsca/tlsca.bgiblockchain.com-cert.pem
: ${CC_SRC_PATH:="github.com/hyperledger/fabric/examples/chaincode/go/chaincode_bgi"}

echo ">>> Channel name : "$CHANNEL_NAME
echo "Chaincode name : "$CHAINCODE_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {

#	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="HealthMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/health.bgiblockchain.com/peers/peer0.health.bgiblockchain.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/health.bgiblockchain.com/users/Admin@health.bgiblockchain.com/msp
		if [ $1 -eq 0 ]; then 
			CORE_PEER_ADDRESS=peer0.health.bgiblockchain.com:7051
		elif [ $1 -eq 1 ]; then
			CORE_PEER_ADDRESS=peer1.health.bgiblockchain.com:7151
		elif [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer2.health.bgiblockchain.com:7251
		elif [ $1 -eq 3 ]; then
			CORE_PEER_ADDRESS=peer3.health.bgiblockchain.com:7351
		elif [ $1 -eq 4 ]; then
			CORE_PEER_ADDRESS=peer4.health.bgiblockchain.com:7051
		elif [ $1 -eq 5 ]; then
			CORE_PEER_ADDRESS=peer5.health.bgiblockchain.com:7151
		elif [ $1 -eq 6 ]; then
			CORE_PEER_ADDRESS=peer6.health.bgiblockchain.com:7251
		elif [ $1 -eq 7 ]; then
			CORE_PEER_ADDRESS=peer7.health.bgiblockchain.com:7351
		elif [ $1 -eq 8 ]; then
			CORE_PEER_ADDRESS=peer8.health.bgiblockchain.com:7451
		elif [ $1 -eq 9 ]; then
			CORE_PEER_ADDRESS=peer9.health.bgiblockchain.com:7551
		fi
#	else
#		CORE_PEER_LOCALMSPID="Org2MSP"
#		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/health.bgiblockchain.com/peers/peer0.health.bgiblockchain.com/tls/ca.crt
#		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/health.bgiblockchain.com/users/Admin@health.bgiblockchain.com/msp
#		if [ $1 -eq 2 ]; then
#			CORE_PEER_ADDRESS=peer0.health.bgiblockchain.com:7051
#		else
#			CORE_PEER_ADDRESS=peer2.health.bgiblockchain.com:8051
#		fi
#	fi

	env |grep CORE
}

createChannel() {
	setGlobals 0

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o ${ORDERER}:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}.tx >&log.txt
	else
		peer channel create -o ${ORDERER}:7050 -t 10s -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
	PEER=$1
	setGlobals $PEER

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o ${ORDERER}:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors_${CHANNEL_NAME}.tx >&log.txt
	else
		peer channel update -o ${ORDERER}:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors_${CHANNEL_NAME}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep 5
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in ${JOIN_PEER[@]}; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep 2
		echo
	done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n ${CHAINCODE_NAME} -v 1.0 -p ${CC_SRC_PATH} >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o ${ORDERER}:7050 -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('HealthMSP.member')" >&log.txt
	else
		peer chaincode instantiate -o ${ORDERER}:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('HealthMSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' >&log.txt
	 local exitcode=$?
     test $exitcode -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$2" && let rc=0
	 test $exitcode -eq 0 && VALUE=$(cat log.txt | egrep '^[0-9]+$') # >=1.2
	 test "$VALUE" = "$2" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
}

chaincodeInvoke () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o ${ORDERER}:7050 -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	else
		peer chaincode invoke -o ${ORDERER}:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

validateArgs () {
	if [ -z "${CHANNEL_NAME}" ]; then
				printHelp
		exit 1
	fi
	if [ -z "${CHAINCODE_NAME}" ]; then
				printHelp
		exit 1
	fi
}

upgradeChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode upgrade -o ${ORDERER}:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -v 2.0 -p ${CC_SRC_PATH}  -c '{"Args":["init","a","100","b","200"]}' -P "OR	('HealthMSP.member')" >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}


checkOSNAvailability() {
	#Use orderer's MSP for fetching system channel config block
	CORE_PEER_LOCALMSPID="OrdererMSP"
	CORE_PEER_TLS_ROOTCERT_FILE=$ORDERER_CA
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bgiblockchain.com/orderers/${ORDERER}/msp

	local rc=1
	local starttime=$(date +%s)

	# continue to poll
	# we either get a successful response, or reach TIMEOUT
	while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
	do
		 sleep 3
		 echo "Attempting to fetch system channel 'testchainid' ...$(($(date +%s)-starttime)) secs"
		 if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
			 peer channel fetch 0 -o ${ORDERER}:7050 -c "testchainid" >&log.txt
		 else
			 peer channel fetch 0 0_block.pb -o ${ORDERER}:7050 -c "testchainid" --tls --cafile $ORDERER_CA >&log.txt
		 fi
		 test $? -eq 0 && VALUE=$(cat log.txt | awk '/Received block/ {print $NF}')
		 test "$VALUE" = "0" && let rc=0
	done
	cat log.txt
	verifyResult $rc "Ordering Service is not available, Please try again ..."
	echo "===================== Ordering Service is up and running ===================== "
	echo
}


validateArgs



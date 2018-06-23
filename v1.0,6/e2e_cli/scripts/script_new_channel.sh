# author: Logan Tang 20180607-11:37
# usage: Create new channel to container

CHANNEL_NAME="$1"
CHAINCODE_NAME="$2"
: ${CHANNEL_NAME:="bgihealth"}
: ${CHAINCODE_NAME:="token_health"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bgiblockchain.com/orderers/orderer0.bgiblockchain.com/msp/tlscacerts/tlsca.bgiblockchain.com-cert.pem

echo
echo "====== start create new channel ======"
echo "CHANNEL_NAME name : "$CHANNEL_NAME
echo "CHAINCODE_NAME name : "$CHAINCODE_NAME
echo

function printHelp () {
	echo "arg1/arg2 should not be empty,arg1 for channel name,arg2 for chaincode name"
}

function validateArgs () {
	if [ -z "${CHANNEL_NAME}" ]; then
				printHelp
		exit 1
	fi
	if [ -z "${CHAINCODE_NAME}" ]; then
				printHelp
		exit 1
	fi
}

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {
		CORE_PEER_LOCALMSPID="HealthMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/health.bgiblockchain.com/peers/peer0.health.bgiblockchain.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/health.bgiblockchain.com/users/Admin@health.bgiblockchain.com/msp
		if [ $1 -eq 0 ]; then 
			CORE_PEER_ADDRESS=peer0.health.bgiblockchain.com:7051
		elif [ $1 -eq 1 ]; then
			CORE_PEER_ADDRESS=peer1.health.bgiblockchain.com:7051
		elif [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer2.health.bgiblockchain.com:7151
		elif [ $1 -eq 3 ]; then
			CORE_PEER_ADDRESS=peer3.health.bgiblockchain.com:7151
		elif [ $1 -eq 4 ]; then
			CORE_PEER_ADDRESS=peer4.health.bgiblockchain.com:7251
		elif [ $1 -eq 5 ]; then
			CORE_PEER_ADDRESS=peer5.health.bgiblockchain.com:7251
		elif [ $1 -eq 6 ]; then
			CORE_PEER_ADDRESS=peer6.health.bgiblockchain.com:7351
		elif [ $1 -eq 7 ]; then
			CORE_PEER_ADDRESS=peer7.health.bgiblockchain.com:7351
		elif [ $1 -eq 9 ]; then
			CORE_PEER_ADDRESS=peer9.health.bgiblockchain.com:7451
		elif [ $1 -eq 10 ]; then
			CORE_PEER_ADDRESS=peer10.health.bgiblockchain.com:7051
		elif [ $1 -eq 11 ]; then
			CORE_PEER_ADDRESS=peer11.health.bgiblockchain.com:7151
		elif [ $1 -eq 12 ]; then
			CORE_PEER_ADDRESS=peer12.health.bgiblockchain.com:7251
		elif [ $1 -eq 13 ]; then
			CORE_PEER_ADDRESS=peer13.health.bgiblockchain.com:7351	
		fi
	env |grep CORE
}

createChannel() {
	setGlobals 0
    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer0.bgiblockchain.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}.tx >&log.txt
	else
		peer channel create -o orderer0.bgiblockchain.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts//${CHANNEL_NAME}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
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
		peer channel update -o orderer0.bgiblockchain.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors_${CHANNEL_NAME}.tx >&log.txt
	else
		peer channel update -o orderer0.bgiblockchain.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors_${CHANNEL_NAME}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
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
	for ch in 0 1 2 3 4 5 6 7; do
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
	peer chaincode install -n $CHAINCODE_NAME -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_bgi >&log.txt
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
		peer chaincode instantiate -o orderer0.bgiblockchain.com:7050 -C $CHANNEL_NAME -n $CHAINCODE_NAME -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('HealthMSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer0.bgiblockchain.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('HealthMSP.member')" >&log.txt
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
     peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["query","a"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
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
		peer chaincode invoke -o orderer0.bgiblockchain.com:7050 -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	else
		peer chaincode invoke -o orderer0.bgiblockchain.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

validateArgs

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
installChaincode 0
echo "Install chaincode on org2/peer2..."
installChaincode 2

#Instantiate chaincode on Peer2/Org2
echo "Instantiating chaincode on org2/peer2..."
instantiateChaincode 2

#Query on chaincode on Peer0/Health
echo "Querying chaincode on org1/peer0..."
chaincodeQuery 0 100

#Invoke on chaincode on Peer0/Health
echo "Sending invoke transaction on org1/peer0..."
chaincodeInvoke 0

## Install chaincode on Peer3/Org2
echo "Installing chaincode on org2/peer3..."
installChaincode 1
installChaincode 3
installChaincode 4
installChaincode 5
installChaincode 6
installChaincode 7

#Query on chaincode on Peer3/Org2, check if the result is 90
echo "Querying chaincode on org2/peer3..."
chaincodeQuery 1 90


echo
echo "===================== All GOOD ===================== "
echo

exit 0

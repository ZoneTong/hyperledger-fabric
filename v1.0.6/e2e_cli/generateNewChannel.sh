# author: Logan Tang 20180607-11:37
# usage: Generate configuration for new channel

#lowercase
CHANNEL_NAME=$1
DATE=`date '+%Y%m%d_%H%M%S'`

echo
echo " *** start create new channel configuration,time: $DATE,CHANNEL_NAME:$CHANNEL_NAME ***"
echo

export FABRIC_ROOT=$PWD/../..
export FABRIC_CFG_PATH=$PWD


OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

function printHelp () {
	echo "params error: arg1 should not be empty,arg1 for channel name"
}

function validateArgs () {
	if [ -z "${CHANNEL_NAME}" ]; then
				printHelp
		exit 1
	fi
}

#backup the old channel information
function backup () {
    mv channel-artifacts channel-artifacts.back.$DATE
	mkdir channel-artifacts
	cp channel-artifacts.back.${DATE}/genesis.block channel-artifacts/genesis.block
}


## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {

	CONFIGTXGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/configtxgen
	if [ -f "$CONFIGTXGEN" ]; then
            echo "Using configtxgen -> $CONFIGTXGEN"
	else
	    echo "Building configtxgen"
	    make -C $FABRIC_ROOT release
	fi

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
#	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/genesis.block

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction ${CHANNEL_NAME}.tx ###"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for HealthMSP   ##########"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/HealthMSPanchors_${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME -asOrg HealthMSP

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org2MSP   ##########"
	echo "#################################################################"
	echo
}

validateArgs
#backup
generateChannelArtifacts

echo
echo " *** create new channel configuration success *** "
echo


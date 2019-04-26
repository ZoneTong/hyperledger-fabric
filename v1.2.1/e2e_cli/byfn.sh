#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script will orchestrate a sample end-to-end execution of the Hyperledger
# Fabric network.
#
# The end-to-end verification provisions a sample Fabric network consisting of
# two organizations, each maintaining two peers, and a “solo” ordering service.
#
# This verification makes use of two fundamental tools, which are necessary to
# create a functioning transactional network with digital signature validation
# and access control:
#
# * cryptogen - generates the x509 certificates used to identify and
#   authenticate the various components in the network.
# * configtxgen - generates the requisite configuration artifacts for orderer
#   bootstrap and channel creation.
#
# Each tool consumes a configuration yaml file, within which we specify the topology
# of our network (cryptogen) and the location of our certificates for various
# configuration operations (configtxgen).  Once the tools have been successfully run,
# we are able to launch our network.  More detail on the tools and the structure of
# the network will be provided later in this document.  For now, let's get going...

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../../release/linux-amd64/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  byfn.sh up|down|restart|generate|upgrade [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-i <imagetag>]"
  echo "  byfn.sh -h|--help (print this message)"
  echo "    <mode> - one of 'up', 'down', 'restart' or 'generate'"
  echo "      - 'up' - bring up the network with docker-compose up"
  echo "      - 'down' - clear the network with docker-compose down"
  echo "      - 'restart' - restart the network"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "      - 'upgrade'  - upgrade the network from v1.0.x to v1.1"
  echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
  echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
  echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
  echo "    -l <language> - the chaincode language: golang (default) or node"
  echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
  echo
  echo "Typically, one would first generate the required certificates and "
  echo "genesis block, then bring up the network. e.g.:"
  echo
  echo "	byfn.sh generate -c mychannel"
  echo "	byfn.sh up -c mychannel -s couchdb"
  echo "        byfn.sh up -c mychannel -s couchdb -i 1.1.0-alpha"
  echo "	byfn.sh up -l node"
  echo "	byfn.sh down -c mychannel"
  echo "        byfn.sh upgrade -c mychannel"
  echo
  echo "Taking all defaults:"
  echo "	byfn.sh generate"
  echo "	byfn.sh up"
  echo "	byfn.sh down"
}

# Ask user for confirmation to proceed
function askProceed () {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
    y|Y|"" )
      echo "proceeding ..."
    ;;
    n|N )
      echo "exiting..."
      exit 1
    ;;
    * )
      echo "invalid response"
      askProceed
    ;;
  esac
}

# Versions of fabric known not to work with this release of first-network
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\.0-preview ^1\.1\.0-alpha"


# Upgrade the network from v1.0.x to v1.1
# Stop the orderer and peers, backup the ledger from orderer and peers, cleanup chaincode containers and images
# and relaunch the orderer and peers with latest tag
function upgradeNetwork () {
  # docker inspect  -f '{{.Config.Volumes}}' orderer.bgiblockchain.com |grep -q '/var/hyperledger/production'
  # if [ $? -ne 0 ]; then
    # echo "ERROR !!!! This network does not appear to be using volumes for its ledgers, did you start from fabric-samples >= v1.0.6?"
    # exit 1
  # fi

  LEDGERS_BACKUP=./ledgers-backup

  # create ledger-backup directory
  mkdir -p $LEDGERS_BACKUP

  export IMAGE_TAG=$IMAGETAG
  if [ "${IF_COUCHDB}" == "couchdb" ]; then
      COMPOSE_FILES="-f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH"
  else
      COMPOSE_FILES="-f $COMPOSE_FILE"
  fi

  # removing the cli container
  # docker-compose $COMPOSE_FILES stop cli2
  docker stop cli2
  docker rm -f cli2

  echo "Upgrading orderer"
  for ORDER in orderer0 orderer2; do
    # co=`echo ${ORDER}|awk -F. '{print $1}'`
    docker-compose $COMPOSE_FILES stop ${ORDER}.bgiblockchain.com
    # mkdir -p $LEDGERS_BACKUP/${ORDER}/pro
    docker cp -a ${ORDER}:/var/hyperledger/production $LEDGERS_BACKUP/${ORDER}/
    docker rm -f ${ORDER}
    # docker-compose $COMPOSE_FILES up -d --no-deps ${ORDER}.bgiblockchain.com
  done


  for PEER in peer0 peer1 peer2 peer3; do
    echo "stoping peer images $PEER"

    # Stop the peer and backup its ledger
    docker-compose $COMPOSE_FILES stop $PEER.health.bgiblockchain.com
    # mkdir -p $LEDGERS_BACKUP/$PEER/pro
    docker cp -a $PEER:/var/hyperledger/production $LEDGERS_BACKUP/$PEER/

    # Remove any old containers and images for this peer
    CC_CONTAINERS=$(docker ps | grep dev-$PEER | awk '{print $1}')
    if [ -n "$CC_CONTAINERS" ] ; then
        docker rm -f $CC_CONTAINERS
    fi
    CC_IMAGES=$(docker images | grep dev-$PEER | awk '{print $1}')
    if [ -n "$CC_IMAGES" ] ; then
        docker rmi -f $CC_IMAGES
    fi

    # Start the peer again
    docker rm -f $PEER
    # docker-compose $COMPOSE_FILES up -d --no-deps $PEER.health.bgiblockchain.com
  done

  echo "switching crypto-config"
  # rm -rf crypto-config  &&  cp -rf crypto-config-1.2  crypto-config
  docker-compose $COMPOSE_FILES up -d --no-deps cli2
  for ORDER in orderer0 orderer2; do
    docker-compose $COMPOSE_FILES up -d --no-deps ${ORDER}.bgiblockchain.com
  done
  
  for PEER in peer0 peer1 peer2 peer3; do
    docker-compose $COMPOSE_FILES up -d --no-deps $PEER.health.bgiblockchain.com
  done
  
#  docker-compose $COMPOSE_FILES up -d --no-deps zookeeper0.bgiblockchain.com zookeeper1.bgiblockchain.com zookeeper2.bgiblockchain.com kafka0.bgiblockchain.com kafka1.bgiblockchain.com kafka2.bgiblockchain.com kafka3.bgiblockchain.com
  sleep 20

  UPGRADE_SH="no_sh"
  if [ $TOVERSION == "1.1.1" ]; then
    UPGRADE_SH="scripts/upgrade_to_v11.sh"
  elif [  $TOVERSION == "1.2.1" ]; then
    UPGRADE_SH="scripts/upgrade_to_v12.bgi.sh"
  elif [  $TOVERSION == "1.3.0" ]; then
    UPGRADE_SH="scripts/upgrade_to_v13.sh"
  elif [  $TOVERSION == "1.4.0" ]; then
    UPGRADE_SH="scripts/upgrade_to_v14.sh"
  fi

	echo "$TOVERSION"
  fabric=$PWD/../..
  docker pull hyperledger/fabric-ccenv:amd64-$TOVERSION
  docker tag  hyperledger/fabric-ccenv:amd64-$TOVERSION  hyperledger/fabric-ccenv:latest
  
  tar xzf $fabric/release/linux-amd64/bin/fabric-$TOVERSION-bin.tgz -C $fabric/release/linux-amd64/bin/
  cp configtx.$TOVERSION.yaml configtx.yaml
  if [ $TOVERSION == "1.1.1" ]; then
    exit
  fi

  # 升级已有数据
  CHS=($CHANNEL_NAME )
  for ch in ${CHS[@]}; do
    CC=token_$ch
    docker exec cli2 $UPGRADE_SH $ch $CC $CLI_DELAY $LANGUAGE $CLI_TIMEOUT
  done

  # 其他channel
#  docker exec cli2 scripts/upgrade_to_v11.sh t2  token_t2


  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Test failed"
    exit 1
  fi
}


# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform
OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
# default for delay between commands
CLI_DELAY=3
# channel name defaults to "mychannel"
CHANNEL_NAME="bgihealth"
CC="token_bgihealth"
# use this as the default docker-compose yaml definition
COMPOSE_FILE=docker-compose-kafka.yaml
#
COMPOSE_FILE_COUCH=docker-compose-couch.yaml
# use golang as the default language for chaincode
LANGUAGE=golang
# default image tag
IMAGETAG="latest"
# Parse commandline args
if [ "$1" = "-m" ];then	# supports old usage, muscle memory is powerful!
    shift
fi
MODE=$1;shift
# Determine whether starting, stopping, restarting or generating for announce
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting"
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block for"
elif [ "$MODE" == "upgrade" ]; then
  EXPMODE="Upgrading the network"
else
  printHelp
  exit 1
fi

while getopts "h?m:c:t:d:f:s:l:i:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    c)  CHANNEL_NAME=$OPTARG
    ;;
    t)  CLI_TIMEOUT=$OPTARG
    ;;
    d)  CLI_DELAY=$OPTARG
    ;;
    f)  COMPOSE_FILE=$OPTARG
    ;;
    s)  IF_COUCHDB=$OPTARG
    ;;
    l)  LANGUAGE=$OPTARG
    ;;
    # i)  IMAGETAG=`uname -m`"-"$OPTARG
    i)  IMAGETAG=amd64-$OPTARG
      TOVERSION=$OPTARG
    ;;
  esac
done

# Announce what was requested

  if [ "${IF_COUCHDB}" == "couchdb" ]; then
        echo
        echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database '${IF_COUCHDB}'"
  else
        echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds"
  fi
# ask for confirmation to proceed
#askProceed

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCerts
  replacePrivateKey
  generateChannelArtifacts
elif [ "${MODE}" == "restart" ]; then ## Restart the network
  networkDown
  networkUp
elif [ "${MODE}" == "upgrade" ]; then ## Upgrade the network from v1.0.x to v1.1
  upgradeNetwork
else
  printHelp
  exit 1
fi

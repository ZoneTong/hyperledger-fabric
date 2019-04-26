function clear(){
    ./network_setup.sh down && rm -rf /bgi/blockchain_data /bgi/kblockchain_data
    prj=/opt/gopath/src/github.com/hyperledger/fabric/bgi_client_health
    cd $prj/redisdocker && docker-compose down && rm -rf /bgi/redis_data
    cd $prj && bash cmd.sh stop  && rm -rf  /bgi/logs/bgi_client_health/*
}

function backup_pack(){
    node=$1
    if [ "$node" == "" ];then
        echo error node
        exit 1
    fi
    docker stop $node
    docker rm -f $(docker ps -a| grep "dev-${node}" |awk '{print $1}')
    docker rmi -f $(docker images| grep "dev-${node}" |awk '{print $3}')
    tar czf moving.tar /bgi/blockchain_data/$node
    scp moving.tar root@192.168.29.244:/opt/gopath/src/github.com/hyperledger/fabric/examples/e2e_cli

    rm -rf /bgi/blockchain_data/$node
}

function tagdocker(){
    Version=$1
    #ARCH=`uname -m`
    ARCH=$2
    : ${Version:="1.0.0-beta"}
    : ${ARCH:=`uname -m`}
    : ${CA_TAG:="$ARCH-$Version"}
    : ${FABRIC_TAG:="$ARCH-$Version"}

    for IMAGES in peer orderer  ccenv tools ca; do
        echo "==> FABRIC IMAGE: $IMAGES"
        echo
        docker pull hyperledger/fabric-$IMAGES:$FABRIC_TAG
        docker tag hyperledger/fabric-$IMAGES:$FABRIC_TAG hyperledger/fabric-$IMAGES:latest
    done 

    for IMAGES in kafka zookeeper; do
        echo "==> FABRIC IMAGE: $IMAGES"
        echo
        docker pull hyperledger/fabric-${IMAGES}:latest
    done 
}

function rollback(){
    for CON in orderer0 orderer2 peer0 peer1 peer2 peer3; do
        mkdir -p /bgi/blockchain_data/$CON
        cp -rf ./ledgers-backup/$CON/production /bgi/blockchain_data/$CON/pro
    done
}

IMAGES_TAG=amd64-1.2.1
#IMAGES_TAG=x86_64-1.1.1
function start(){
    docker pull hyperledger/fabric-zookeeper
    docker pull hyperledger/fabric-kafka 
    chmod 755 *.sh *.py scripts/*.sh
    #./generateNewChannel.sh bgihealth token_bgihealth
    IMAGE_TAG=$IMAGES_TAG ./network_setup.sh up $@  && sleep 10 && docker exec -it cli2 scripts/script_kafka.sh $@
    # IMAGE_TAG=amd64-1.2.1 docker-compose --project-name=e2ecli -f docker-compose-cli.yaml up -d && docker exec -it cli2 scripts/script.sh $@

    prj=/opt/gopath/src/github.com/hyperledger/fabric/bgi_client_health
    cd $prj/redisdocker && docker-compose up -d  master

    mkdir -p /bgi/logs/bgi_client_health 
    #cd $prj && bash cmd.sh boot 245
}

function kstart(){
    # tar xzf testcerts.tar
    # rm -rf crypto-config && ./generateArtifacts.sh bgihealth token_bgihealth 1
    docker tag  hyperledger/fabric-ccenv:$IMAGES_TAG  hyperledger/fabric-ccenv:latest
    IMAGE_TAG=$IMAGES_TAG docker-compose --project-name=e2ecli -f docker-compose-kafka.yaml up -d $@  && sleep 1
}

function kup(){
    cp configtx.1.1.1.yaml configtx.yaml
    rm -rf crypto-config && ./generateArtifacts.sh bgihealth token_bgihealth 1
    IMAGE_TAG=$IMAGES_TAG docker-compose --project-name=e2ecli -f docker-compose-kafka.yaml up -d $@  && sleep 1 && docker exec -it cli2 scripts/script_kafka.sh $@
}

function kdown(){
    IMAGE_TAG=$IMAGES_TAG docker-compose --project-name=e2ecli -f docker-compose-kafka.yaml down && rm -rf /bgi/blockchain_data && rm -rf /bgi/kblockchain_data
}

function e2eup(){
    IMAGE_TAG=$IMAGES_TAG docker-compose --project-name=e2ecli -f docker-compose-cli.yaml up -d && docker exec -it cli2 scripts/script.sh $@
}

function e2edown(){
    IMAGE_TAG=$IMAGES_TAG docker-compose --project-name=e2ecli -f docker-compose-cli.yaml -f docker-compose-org3.yaml down --volumes
    rm -rf org3-artifacts/crypto-config
    sudo rm -rf /bgi/blockchain_data && sudo rm -rf /bgi/kblockchain_data
    
    ./network_setup.sh down
}

function org3down(){
    docker-compose --project-name=e2ecli -f docker-compose-org3.yaml down --volumes
    rm -rf org3-artifacts/crypto-config
}

function backup_unpack(){
    #./network_setup.sh down #  ./dc.py o down 
    #rm -rf  bgi   /bgi/blockchain_data /bgi/kblockchain_data

    node=$1
    if [ "$node" == "" ];then
            echo error node
            exit 1  
    fi

    tar xzf moving.tar 
    rm -rf /bgi/blockchain_data/$node
    mv bgi/blockchain_data/$node /bgi/blockchain_data/
    ./dc.py o up $node
}

function save(){
    FABRIC_TAG=$1

    for IMAGE in peer orderer  ccenv tools ca; do
        echo "==> FABRIC IMAGE: $IMAGE"
        docker pull hyperledger/fabric-$IMAGE:$FABRIC_TAG
        echo
        docker save -o fabric-$IMAGE-$FABRIC_TAG.tgz hyperledger/fabric-$IMAGE:$FABRIC_TAG
    done

    # save_kafka
}

function save_kafka(){
    FABRIC_TAG=latest
    for IMAGE in kafka zookeeper couchdb; do
        echo "==> FABRIC IMAGE: $IMAGE"
        echo
        docker save -o fabric-$IMAGE-$FABRIC_TAG.tgz hyperledger/fabric-${IMAGE}:$FABRIC_TAG
    done 
}

function load(){
    FABRIC_TAG=$1

    for IMAGE in peer orderer  ccenv tools ca; do
        echo "==> FABRIC IMAGE: $IMAGE"
        echo
        docker load --input fabric-$IMAGE-$FABRIC_TAG.tgz
    done

}

function load_kafka(){
    FABRIC_TAG=latest
    for IMAGE in kafka zookeeper couchdb; do
        echo "==> FABRIC IMAGE: $IMAGE"
        echo
        docker load --input fabric-$IMAGE-$FABRIC_TAG.tgz
    done
}

function save_all(){
    save_kafka
    save x86_64-1.1.1
    save  amd64-1.2.1
    save  amd64-1.3.0
    save  amd64-1.4.0
}

function load_all(){
    load_kafka
    load x86_64-1.1.1
    load  amd64-1.2.1
    load  amd64-1.3.0
    load  amd64-1.4.0
}

function test(){
    PEER=$1
    ORG=$2
    if [ $ORG -eq 1 ] || [ $ORG -eq 2 ];then
        echo aaaa
    else
        echo bbb
    fi
}

$@

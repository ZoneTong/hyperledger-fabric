#!/bin/bash
#./replaceip.sh 172.16.186.152 172.16.186.183
oip=$1
pip=$2
sed -i "s/${oip}/192.168.31.103/g"  docker-compose-peer.yaml docker-compose-orderer.yaml

sed -i "s/${pip}/192.168.31.104/g" docker-compose-peer.yaml docker-compose-orderer.yaml
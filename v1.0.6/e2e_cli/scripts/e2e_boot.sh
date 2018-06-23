#!/bin/bash

echo '###==================###'
echo '###==================###'

# start blockchain and client when reboot 
#ip=$(ip a | grep inet | grep -v inet6 | grep -v 127 | grep -v 172 |sed 's/^[ \t]*//g' | cut -d ' ' -f2 |cut -d '/' -f1)
ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"|tail -1`
export TZ='Asia/Shanghai'
DATETIME=`date '+%Y%m%d%H%M%S'`
echo 'ip:'${ip} ${DATETIME}', boot fabric start'

# 分order机和peer机启动
#ordererip=192.168.31.103
#is_orderer=true

if [ $ip == 192.168.31.103 ] || [ $ip == 172.16.186.152 ] || [ $ip == 192.168.1.110 ]; then
#if [ $2 == 1 ];then
	is_orderer=true
else
	is_orderer=false
fi

if [ $ip == 192.168.31.103 ] || [ $ip == 192.168.31.104 ]; then
#if [ "$1" == "" ] || [ $1 != test ];then
	ordererip=192.168.31.103
elif [ $ip == 192.168.1.110 ] || [ $ip == 192.168.1.114 ]; then
	ordererip=192.168.1.110
else
	ordererip=172.16.186.152
fi


### order
if $is_orderer; then
	echo 'orderer starting...'	
	
	# e2e
	cd /opt/gopath/src/github.com/hyperledger/fabric/examples/e2e_cli
	docker-compose -f docker-compose-orderer.yaml up -d
	nohup ./order_monitor.py $ordererip o >& order_monitor.log$1 2>&1 &

### peer
else
	echo 'peer starting'

	# e2e
	cd /opt/gopath/src/github.com/hyperledger/fabric/examples/e2e_cli
	docker-compose -f docker-compose-peer.yaml up -d
	nohup ./order_monitor.py $ordererip p >& order_monitor.log$1 2>&1 &
fi

# redis
cd /usr/local/redis-3.2.11/bin
./redis-server redis.conf 

export GOROOT=/usr/go
export GOPATH=/opt/gopath
export GOBIN=/opt/gopath/bin
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# bgi client
# 文件夹名为这次启动时间，输出文件名为上次启动时间
echo 'bgi_client_health starting'
sleep 3
cd /opt/gopath/src/github.com/hyperledger/fabric/bgi_client_health/test
./boot.sh $1 $2
#logdir=/bgi/bgi_client_health/${ip}/${DATETIME}
#mkdir -p ${logdir}
#mv out_client.out  ${logdir}/out_client.out.${DATETIME}
#mv log_client.log  ${logdir}/log_client.log.${DATETIME}
#nohup ./client_bc -conf config_zht -ip 1 >> out_client.out 2>&1 &
#echo $! > pidfile.txt


echo 'bgilifechain starting'
sleep 3
cd /opt/gopath/src/github.com/hyperledger/fabric/bgi_client_health/bc
go build
#./bc -C bgilifechain -o ${ordererip}:7050 -sar 127.0.0.1:8006 -fn getmsg -n mycc -p1 test_str
#./bc -C bgilifechain -o ${ordererip}:7050 -sar 127.0.0.1:8016 -fn getmsg -n mycc -p1 test_str

cd /opt/gopath/src/github.com/hyperledger/fabric/bgi_client_health/test
./bc_readwrite.sh
#go run check_zht.go funcs.go

nohup ./monitor.sh > monitor.log$1 2>&1 &

echo 'boot fabric end'
echo '###==================###'
echo '###==================###'
exit 0

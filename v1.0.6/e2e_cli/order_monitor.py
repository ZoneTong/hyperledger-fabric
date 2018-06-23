#!/usr/bin/python
# -*- coding: UTF-8 -*-

import sys
import os
import time
import socket

def check_server(address,port):
   s = socket.socket()
   #print "attempting to connect to %s on port %s" %(address,port)
 
   try:
     s.connect((address,port))
     #print "connected"
     return True
   except socket.error,e:
     #print "failed"
     return False
   

order_ip = sys.argv[1]
node = ""
if len(sys.argv) < 2 or sys.argv[2] == "o":
    node="orderer"
elif sys.argv[2]=="p":
    node="peer"
elif sys.argv[2]=="c":
    node="peer_care"
else:
    node=sys.argv[2]


e2e_path="/opt/gopath/src/github.com/hyperledger/fabric/examples/e2e_cli/"
LIMIT_MAX = 200
failed = False
FAILED_LIMIT = 15     # 失败下限
failed_cnt = 0        # 连续测试端口失败次数
OK_LIMIT = 10         # 成功下限
ok_cnt = 0            # 连续测试端口成功次数
sleeptime = 1

peer_ports = [8006, 8016, 8026, 8036]
peer_failedcnts = [0,0,0,0]
peer_nodes = []
if node == "orderer":
    peer_nodes.append('peer0')
    peer_nodes.append('peer2')
    peer_nodes.append('peer4')
    peer_nodes.append('peer6')
elif node == "peer":
    peer_nodes.append('peer1')
    peer_nodes.append('peer3')
    peer_nodes.append('peer5')
    peer_nodes.append('peer7')
elif node == "peer_care":
    peer_nodes.append('peer10')
    peer_nodes.append('peer11')
    peer_nodes.append('peer12')
    peer_nodes.append('peer13')

def check_peers(ports, failedcnts, peers):
    for i in range(len(ports)):
        if not check_server("127.0.0.1", ports[i]):
            failedcnts[i] += 1
            if failedcnts[i] >= FAILED_LIMIT: #restart peer
                peer=peers[i]
                cmd='mv /bgi/blockchain_data/%s/logs/peer.log > /bgi/downpeerlog/%s_%s.log' % (peer,peer, time.strftime("%m%d_%H%M%S", time.localtime()))
                print os.popen(cmd).readlines()

                cmd = 'docker-compose -f '+e2e_path+'docker-compose-%s.yaml up %s.health.businessblockchain.com' % (node,peer)
                print os.popen(cmd).readlines()
                print time.strftime("\n%Y-%m-%d %H:%M:%S", time.localtime()), cmd
                failedcnts[i] = 0 
        else:
            failedcnts[i] = 0  

      

while True:
    # 103
    if node == "orderer":
        if not check_server(order_ip, 7050):
            ok_cnt = 0
            failed_cnt += 1
            if failed_cnt >= FAILED_LIMIT:
                time.sleep(sleeptime )
                cmd = 'docker-compose -f '+e2e_path+'docker-compose-orderer.yaml restart'
                print os.popen(cmd).readlines()
                print '\n'
                print time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()), cmd
        else:
            ok_cnt += 1
            failed_cnt = 0

    # 104
    elif check_server(order_ip, 7050):
        ok_cnt += 1
        failed_cnt = 0
        if failed and ok_cnt >= OK_LIMIT: 
            cmd = 'docker-compose -f '+e2e_path+'docker-compose-peer.yaml restart'
            print os.popen(cmd).readlines()
            print '\n'
            print time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()), cmd
            failed = False
            failed_cnt = 0
    else:
        failed_cnt += 1
        if failed_cnt >= FAILED_LIMIT:
            failed = True
        ok_cnt = 0
      
    #print 'ok ' + str(ok_cnt) + ', failed ' + str(failed_cnt) + ' flag ' + str(failed)   
    
    check_peers(peer_ports, peer_failedcnts, peer_nodes)

    #防范超限
    if failed_cnt >= LIMIT_MAX:
        failed_cnt = LIMIT_MAX
    if ok_cnt >= LIMIT_MAX:
        ok_cnt = LIMIT_MAX
                   
    time.sleep(sleeptime)
    

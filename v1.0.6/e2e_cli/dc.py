#!/usr/bin/python
# -*- coding: UTF-8 -*-

import sys
import os
import time

node=sys.argv[1]
subcmd=sys.argv[2]
services=sys.argv[3:]

if node=='o':
	node='orderer'
elif node.startswith('p'):
	node='peer' + node[1:]
elif node=='c':
    node='care'
elif node=='k':
    node='kafka'

if subcmd == 'up':
	subcmd ='up -d'
    
for index in range(len(services)):
    if services[index].startswith('p'):
        services[index] = 'peer'+services[index][1:]+'.health.businessblockchain.com'

s_services = ''
for ser in services:
    s_services += ' ' + ser

#if node == 'peer1' or node == 'peer2' or node == 'peer3' or node == 'peer4' or node == 'peer5' or node == 'peer6' or node == 'peer7':
#    with open('docker-compose-peer-tpl.yaml', 'rb') as f:
#        content = f.read()
#        content = content.replace('$PEER', node)
#        with open('docker-compose-'+node+'.yaml', 'wb') as fw:
#            fw.write(content)


if node == 'loop':
    arr = sys.argv[2:]
    i = 0    
    while 1 :
        if i/2 >= len(arr):
            i = 0
        index = arr[i/2]
        #if i%2 == 1:
        #    cmd = 'docker-compose -f docker-compose-peer'+index+'.yaml up -d'
        #else:
        #    cmd = 'docker-compose -f docker-compose-peer'+index+'.yaml down'
        #print os.popen(cmd).readlines()
        
        time.sleep(30)
        i += 1
else:
    cmd = 'docker-compose -f docker-compose-'+node+'.yaml '+subcmd + s_services
    if node == 'orderer':
    	print os.popen(cmd).readlines()
    #	print os.popen('docker-compose -f docker-compose-peer0.yaml '+subcmd).readlines()
    else:
    	print os.popen(cmd).readlines()

	

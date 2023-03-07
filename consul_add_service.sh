#!/bin/bash

#添加服务举例
#curl -X PUT -d '{"id": "server1","name": "haproxy_exporter","address": "10.10.100.221","port": ''9101,"tags": ["haproxy_exporter"], "checks": [{"http": "http://10.10.100.221:9101/","interval": "5s"}]}'     http://localhost:8500/v1/agent/service/register

#删除服务
#curl -X PUT http://localhost:8500/v1/agent/service/deregister/server1

for i in 1 2 3
do
  curl -X PUT -d '{"id": "server'${i}'","name": "haproxy_exporter","address": "10.10.100.22'${i}'","port": 9101,"tags": ["haproxy_exporter"], "checks": [{"http": "http://10.10.100.22'${i}':9101/","interval": "5s"}]}'  http://localhost:8500/v1/agent/service/register
done

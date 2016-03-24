# RabbitMQ docker image
This is a RabbitMQ docker image for setting up rabbitmq cluster. This image also includes filebeat to transfer log to logstash for ELK analysis.

## Quick start
There are some parameters for passing into container.

RABBITMQ_ERLANG_COOKIE: The key between cluster nodes.

CLUSTER_WITH: Point to the cluster starter

### For non-swarm mode
Standalone:
```sh
$ docker create --name rabbitvol goatman/rabbitmq:3.6.1
$ docker run --rm -ti --name rabbit --hostname rabbit -p 5672:5672 -p 15672:15672 -p 25672:25672 -p 4369:4369 -p 9100:9100 -p 9101:9101 -p 9102:9102 -p 9103:9103 -p 9104:9104 -p 9105:9105 -p 1883:1883 -e RABBITMQ_ERLANG_COOKIE=XXXXXXXXX -e CLUSTER_WITH=rabbit1 -e LOGSTASH_STRING=\"aaa:5044\",\"bbb:5044\" goatman/rabbitmq:3.6.1
```
Cluster-Starter:
```sh
$ docker create --name rabbitvol goatman/rabbitmq:3.6.1
$ docker run --rm -ti --name rabbit1 --add-host rabbit2:[ip] -h rabbit1 -p 5672:5672 -p 15672:15672 -p 25672:25672 -p 4369:4369 -p 9100:9100 -p 9101:9101 -p 9102:9102 -p 9103:9103 -p 9104:9104 -p 9105:9105 -p 1883:1883 -e RABBITMQ_ERLANG_COOKIE=xxxxxxxxxx -e CLUSTER_WITH=rabbit1 -e LOGSTASH_STRING=\"aaa:5044\",\"bbb:5044\" goatman/rabbitmq:3.6.1
```
Cluster-Nodes:
```sh
$ docker create --name rabbitvol goatman/rabbitmq:3.6.1
$ docker run --rm -ti --name rabbit2 --add-host rabbit1:[ip] -h rabbit2 -p 5672:5672 -p 15672:15672 -p 25672:25672 -p 4369:4369 -p 9100:9100 -p 9101:9101 -p 9102:9102 -p 9103:9103 -p 9104:9104 -p 9105:9105 -p 1883:1883 -e RABBITMQ_ERLANG_COOKIE=xxxxxxxxxx -e CLUSTER_WITH=rabbit1 -e LOGSTASH_STRING=\"aaa:5044\",\"bbb:5044\" goatman/rabbitmq:3.6.1
```

### Stop container in swarm
```sh
$ docker stop [container_name]
```

### Remove container in swarm
```sh
$ docker rm [container_name]
```

### Execute command in specific container
```sh
$ docker exec [container_name] command
```

### Build in swarm
```sh
$ docker build -t "goatman/rabbitmq:3.6.1" .
```
or you can just use the Makefile by typing command 'make build'

### For swarm mode
Standalone:
```sh
$ docker create --name rabbitvol -e constraint:node==[node] goatman/rabbitmq:3.6.1
$ docker -H tcp://swarmmaster:50000 run -d -p 5672:5672 -p 15672:15672 -p 25672:25672 -p 4369:4369 -p 9100:9100 -p 9101:9101 -p 9102:9102 -p 9103:9103 -p 9104:9104 -p 9105:9105 -p 1883:1883 -e constraint:node==[node] --name rabbit --net oanet -h rabbit -m 1g -e RABBITMQ_ERLANG_COOKIE=xxxxxxxxxx -e CLUSTER_WITH=rabbit -e LOGSTASH_STRING=\"aaa:5044\",\"bbb:5044\" goatman/rabbitmq:3.6.1
```
Cluster-Starter:
```sh
$ docker create --name rabbitvol -e constraint:node==[node] goatman/rabbitmq:3.6.1
$ docker -H tcp://swarmmaster:50000 run -d -p 5672:5672 -p 15672:15672 -p 25672:25672 -p 4369:4369 -p 9100:9100 -p 9101:9101 -p 9102:9102 -p 9103:9103 -p 9104:9104 -p 9105:9105 -p 1883:1883 -e constraint:node==[node] --name rabbit1 --net oanet -h rabbit1 -m 1g -e RABBITMQ_ERLANG_COOKIE=xxxxxxxxxx -e CLUSTER_WITH=rabbit1 -e LOGSTASH_STRING=\"aaa:5044\",\"bbb:5044\" goatman/rabbitmq:3.6.1
```
Cluster-Nodes:
```sh
$ docker create --name rabbitvol -e constraint:node==[node] goatman/rabbitmq:3.6.1
$ docker -H tcp://swarmmaster:50000 run -d -p 5672:5672 -p 15672:15672 -p 25672:25672 -p 4369:4369 -p 9100:9100 -p 9101:9101 -p 9102:9102 -p 9103:9103 -p 9104:9104 -p 9105:9105 -p 1883:1883 -e constraint:node==[node] --name rabbit2 --net oanet -h rabbit2 -m 1g -e RABBITMQ_ERLANG_COOKIE=xxxxxxxxxx -e CLUSTER_WITH=rabbit1 -e LOGSTASH_STRING=\"aaa:5044\",\"bbb:5044\" goatman/rabbitmq:3.6.1
```

### Stop container in swarm
```sh
$ docker -H tcp://swarmmaster:50000 stop [container_name]
```

### Remove container in swarm
```sh
$ docker -H tcp://swarmmaster:50000 rm [container_name]
```

### Execute command in specific container
```sh
$ docker -H tcp://swarmmaster:50000 exec [container_name] command
```

## Reference
https://github.com/bijukunjummen/docker-rabbitmq-cluster

https://github.com/docker-library/rabbitmq

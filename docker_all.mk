d-supervisor:
	cd ~/docker/$@; $(MAKE)

d-syslog: d-supervisor
	cd ~/docker/$@; $(MAKE)

d-consul: d-syslog
	cd ~/docker/$@; $(MAKE)

d-terminal: d-consul
	cd ~/docker/$@; $(MAKE)

d-node: d-terminal
	cd ~/docker/$@; $(MAKE)

u-supervisor:
	cd ~/docker/$@; $(MAKE)

u-syslog: u-supervisor
	cd ~/docker/$@; $(MAKE)

u-consul: u-syslog
	cd ~/docker/$@; $(MAKE)

u-terminal: u-consul
	cd ~/docker/$@; $(MAKE)

d-node: d-terminal
	cd ~/docker/$@; $(MAKE)

rocketchat: d-node
	cd ~/docker/docker-$@; $(MAKE)

hubot-rocketchat: d-node
	cd ~/docker/docker-$@; $(MAKE)

supervisor: 
	cd ~/docker/docker-$@; $(MAKE)

syslog: supervisor
	cd ~/docker/docker-$@; $(MAKE)

consul: syslog
	cd ~/docker/docker-$@; $(MAKE)

diamond: consul
	cd ~/docker/docker-$@; $(MAKE)

terminal: diamond
	cd ~/docker/docker-$@; $(MAKE)

carbon: terminal
	cd ~/docker/docker-$@; $(MAKE)

graphite-api: terminal
	cd ~/docker/docker-$@; $(MAKE)

graphite-web: terminal
	cd ~/docker/docker-$@; $(MAKE)

grafana: terminal
	cd ~/docker/docker-$@; $(MAKE)

grafana2: terminal
	cd ~/docker/docker-$@; $(MAKE)

kibana3: terminal
	cd ~/docker/docker-$@; $(MAKE)

kibana4: terminal
	cd ~/docker/docker-$@; $(MAKE)

influxdb: terminal
	cd ~/docker/docker-$@; $(MAKE)

fullerite: terminal
	cd ~/docker/docker-$@; $(MAKE)

java7: terminal
	cd ~/docker/$@; $(MAKE)

java8: terminal
	cd ~/docker/docker-$@; $(MAKE)

mongodb: terminal
	cd ~/docker/docker-$@; $(MAKE)

zookeeper: java7
	cd ~/docker/docker-$@; $(MAKE)

zkui: java7
	cd ~/docker/docker-$@; $(MAKE)

hadoop: java7
	cd ~/docker/docker-$@; $(MAKE)
	
hbase: hadoop
	cd ~/docker/docker-$@; $(MAKE)

opentsdb: hbase
	cd ~/docker/docker-$@; $(MAKE)

kafka: java7
	cd ~/docker/docker-$@; $(MAKE)

kafka-monitor: java7
	cd ~/docker/docker-$@; $(MAKE)

openldap: u-terminal
	cd ~/docker/docker-$@; $(MAKE)

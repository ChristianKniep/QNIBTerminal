PLAIN_BUILD=cd ~/docker/$@; git checkout master; $(MAKE)
DOCKER_BUILD=cd ~/docker/docker-$@; git checkout master; $(MAKE)

d-supervisor:
	$(PLAIN_BUILD)

d-syslog: d-supervisor
	$(PLAIN_BUILD)

d-consul: d-syslog
	$(PLAIN_BUILD)

d-terminal: d-consul
	$(PLAIN_BUILD)

d-node: d-terminal
	$(PLAIN_BUILD)

u-supervisor:
	$(PLAIN_BUILD)

u-syslog: u-supervisor
	$(PLAIN_BUILD)

u-consul: u-syslog
	$(PLAIN_BUILD)

u-terminal: u-consul
	$(PLAIN_BUILD)

u-samza: u-terminal
	$(PLAIN_BUILD)

convert: u-terminal
	$(DOCKER_BUILD)

rocketchat: d-node
	cd ~/docker/docker-$@; $(MAKE)

hubot-rocketchat: d-node
	cd ~/docker/docker-$@; $(MAKE)

fedora:
	$(DOCKER_BUILD)

supervisor: fedora
	cd ~/docker/docker-$@; $(MAKE)

syslog: supervisor
	cd ~/docker/docker-$@; $(MAKE)

bats: syslog
	cd ~/docker/docker-$@; $(MAKE)

consul: bats
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
	cd ~/docker/docker-$@; $(MAKE)

java8: terminal
	cd ~/docker/docker-$@; $(MAKE)

chronix: java8
	cd ~/docker/docker-$@; $(MAKE)

mongodb: terminal
	cd ~/docker/docker-$@; $(MAKE)

zookeeper: java7
	cd ~/docker/docker-$@; $(MAKE)

zkui: java7
	cd ~/docker/docker-$@; $(MAKE)

hadoop: java7
	cd ~/docker/docker-$@; $(MAKE)
	
samza: hadoop
	$(DOCKER_BUILD)

hbase: hadoop
	cd ~/docker/docker-$@; $(MAKE)

opentsdb: hbase
	cd ~/docker/docker-$@; $(MAKE)

kafka: java7
	cd ~/docker/docker-$@; $(MAKE)

kafka-monitor: java7
	cd ~/docker/docker-$@; $(MAKE)

openldap: u-terminal
	$(DOCKER_BUILD)

etcd: terminal
	$(DOCKER_BUILD)

qnibng: terminal
	$(DOCKER_BUILD)

cluster: terminal
	$(DOCKER_BUILD)

slurm: cluster
	$(DOCKER_BUILD)

slurmctld: slurm
	$(DOCKER_BUILD)

slurmd: slurm
	$(DOCKER_BUILD)

compute: slurmd
	$(DOCKER_BUILD)

hpcg: compute
	$(DOCKER_BUILD)



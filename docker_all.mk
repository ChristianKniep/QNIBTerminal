PLAIN_BUILD=cd ~/docker/$@; git checkout master; git pull; $(MAKE)
DOCKER_BUILD=cd ~/docker/docker-$@; git checkout master; git pull ;$(MAKE)
QNIB_CHECKOUT=if [ ! -d ~/docker/$@ ];then git clone git@github.com:qnib/$@ ~/src/github.com/qnib/$@;ln -sf ~/src/github.com/qnib/$@ ~/docker/;fi
CK_CHECKOUT=if [ ! -d ~/docker/$@ ];then git clone git@github.com:ChristianKniep/$@ ~/src/github.com/ChristianKniep/$@;ln -sf ~/src/github.com/ChristianKniep/$@ ~/docker/;fi

include ~/src/github.com/ChristianKniep/QNIBTerminal/docker_alpine.mk
include ~/src/github.com/ChristianKniep/QNIBTerminal/docker_debian.mk
include ~/src/github.com/ChristianKniep/QNIBTerminal/docker_ubuntu.mk


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

sensu: consul
	cd ~/docker/docker-$@; $(make)

diamond: sensu
	cd ~/docker/docker-$@; $(make)

terminal: diamond
	cd ~/docker/docker-$@; $(MAKE)

carbon: terminal
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

jmxtrans7: java7
	$(DOCKER_BUILD)

kafka: jmxtrans7
	cd ~/docker/docker-$@; $(MAKE)

kafka-monitor: java7
	cd ~/docker/docker-$@; $(MAKE)

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



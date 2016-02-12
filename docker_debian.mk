.PHONY: d-hadoop d-yarn d-java7 d-terminal d-supervisor d-syslog d-consul d-terminal d-node rocketchat hubot-rocketchat

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

rocketchat: d-node
	cd ~/docker/docker-$@; $(MAKE)

hubot-rocketchat: d-node
	cd ~/docker/docker-$@; $(MAKE)

d-java7: d-terminal
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

d-hadoop: d-java7
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

d-yarn: d-java7
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

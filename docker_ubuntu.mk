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

u-java8: u-terminal
	$(PLAIN_BUILD)

convert: u-terminal
	$(DOCKER_BUILD)

openldap: u-terminal
	$(DOCKER_BUILD)

kafka-manager: u-java8
	$(DOCKER_BUILD)

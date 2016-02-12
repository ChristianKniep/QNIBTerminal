alpn-base:
	$(PLAIN_BUILD)

alpn-openrc: alpn-base
	$(PLAIN_BUILD)

alpn-supervisor: alpn-base
	$(PLAIN_BUILD)

alpn-consul: alpn-supervisor
	$(PLAIN_BUILD)

alpn-syslog: alpn-consul
	$(PLAIN_BUILD)

alpn-terminal: alpn-syslog
	$(PLAIN_BUILD)

alpn-jre8: alpn-terminal
	$(PLAIN_BUILD)

alpn-jre7: alpn-syslog
	$(PLAIN_BUILD)

alpn-jdk8: alpn-terminal
	$(PLAIN_BUILD)

alpn-gocd-agent: alpn-jre7
	$(PLAIN_BUILD)

docker-gocd-server: alpn-jre7
	$(PLAIN_BUILD)

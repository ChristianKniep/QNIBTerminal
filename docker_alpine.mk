.PHONY: alpn-base alpn-openrc alpn-consul alpn-syslog alpn-terminal alpn-jre8 alpn-jdk8

alpn-base:
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-openrc: alpn-base
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-supervisor: alpn-base
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-consul: alpn-openrc
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-syslog: alpn-consul
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-terminal: alpn-syslog
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-jre8: alpn-terminal
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-jre7: alpn-syslog
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

gocd-server: alpn-jre7
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-gocd-agent: alpn-jre7
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

graphite-api: alpn-syslog
	$(QNIB_CHECKOUT)
	$(DOCKER_BUILD)

alpn-jdk8: alpn-terminal
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-gocd-agent: alpn-jre7
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

docker-gocd-server: alpn-jre7
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

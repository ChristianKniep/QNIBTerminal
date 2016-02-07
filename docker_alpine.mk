alpn-base:
	$(PLAIN_BUILD)

alpn-openrc: alpn-base
	$(PLAIN_BUILD)

alpn-consul: alpn-openrc
	$(PLAIN_BUILD)

alpn-syslog: alpn-consul
	$(PLAIN_BUILD)

alpn-terminal: alpn-syslog
	$(PLAIN_BUILD)

alpn-jre8: alpn-terminal
	$(PLAIN_BUILD)

alpn-jdk8: alpn-terminal
	$(PLAIN_BUILD)

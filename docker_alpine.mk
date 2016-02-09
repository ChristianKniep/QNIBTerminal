.PHONY: alpn-base alpn-openrc alpn-consul alpn-syslog alpn-terminal alpn-jre8 alpn-jdk8

alpn-base:
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

alpn-openrc: alpn-base
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

#alpn-jre8: alpn-terminal
#	$(QNIB_CHECKOUT)
#	$(PLAIN_BUILD)

alpn-jdk8: alpn-terminal
	$(QNIB_CHECKOUT)
	$(PLAIN_BUILD)

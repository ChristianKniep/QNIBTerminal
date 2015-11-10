TAGS=latest

build:
	@for tag in $(TAGS); do \
		if [ $$tag == "latest" ];then \
			branch="master"; \
		else \
			branch=$$tag; \
		fi; \
		git checkout $$branch >/dev/null; \
		git pull; \
		docker build -q -t $(NAME):$$tag . ; \
		if [ "X$${DOCKER_REG}" != "X" ];then \
			docker tag -f $(NAME) $$DOCKER_REG/$(NAME); \
			docker push $$DOCKER_REG/$(NAME); \
		fi; \
	done;
	git checkout master >/dev/null;
	@echo "Done..."


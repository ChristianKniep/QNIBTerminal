build:
	@for tag in $(TAGS); do \
		if [ "X$(build_tag)" != "X" ];then \
			if [ $(build_tag) != $$tag ];then \
				continue; \
            fi; \
		fi; \
		if [ $$tag == "latest" ];then \
			branch="master"; \
		else \
			branch=$$tag; \
		fi; \
		git checkout $$branch >/dev/null; \
		git pull; \
		docker build -q -t $(NAME):$$tag . ; \
		if [ "X$${DOCKER_REG}" != "X" ];then \
			docker tag -f $(NAME):$$tag $$DOCKER_REG/$(NAME):$$tag; \
			docker push $$DOCKER_REG/$(NAME):$$tag; \
		fi; \
	done;
	git checkout master >/dev/null;
	@echo "Done..."


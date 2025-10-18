.PHONY: test test-file lint format check docker-build dev

DOCKER ?= docker
DOCKER_IMAGE ?= github-actions-nvim-test

docker-build:
	$(DOCKER) build -t $(DOCKER_IMAGE) .

test: docker-build
	$(DOCKER) run --rm $(DOCKER_IMAGE)

test-file: docker-build
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/parser_spec.lua"; \
		exit 1; \
	fi
	$(DOCKER) run --rm -e TEST_FILE="$(FILE)" $(DOCKER_IMAGE)

# Run linter
lint:
	eval $$(./luarocks path) && luacheck lua/

# Format code
format:
	@stylua lua/ spec/

# Check formatting
check:
	@stylua --check lua/ spec/

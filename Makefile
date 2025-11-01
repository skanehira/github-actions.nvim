.PHONY: test test-file lint format check docker-build dev

DOCKER ?= docker
DOCKER_IMAGE ?= github-actions-nvim-test
PWD ?= $(shell pwd)

docker-build:
	$(DOCKER) build -t $(DOCKER_IMAGE) .

test: docker-build
	@mkdir -p "$(PWD)/.test-tmp"
	$(DOCKER) run --rm \
		-v "$(PWD)/lua:/workspace/lua:ro" \
		-v "$(PWD)/spec:/workspace/spec:ro" \
		-v "$(PWD)/scripts:/workspace/scripts:ro" \
		-v "$(PWD)/.luacheckrc:/workspace/.luacheckrc:ro" \
		-v "$(PWD)/.busted:/workspace/.busted:ro" \
		-v "$(PWD)/.test-tmp:/tmp:rw" \
		$(DOCKER_IMAGE)

test-file: docker-build
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/parser_spec.lua"; \
		exit 1; \
	fi
	@mkdir -p "$(PWD)/.test-tmp"
	$(DOCKER) run --rm \
		-v "$(PWD)/lua:/workspace/lua:ro" \
		-v "$(PWD)/spec:/workspace/spec:ro" \
		-v "$(PWD)/scripts:/workspace/scripts:ro" \
		-v "$(PWD)/.luacheckrc:/workspace/.luacheckrc:ro" \
		-v "$(PWD)/.busted:/workspace/.busted:ro" \
		-v "$(PWD)/.test-tmp:/tmp:rw" \
		-e TEST_FILE="$(FILE)" \
		$(DOCKER_IMAGE)

# Run linter
lint: docker-build
	$(DOCKER) run --rm \
		-v "$(PWD)/lua:/workspace/lua:ro" \
		-v "$(PWD)/.luacheckrc:/workspace/.luacheckrc:ro" \
		$(DOCKER_IMAGE) sh -c 'eval $$(luarocks path --tree /workspace/lua_modules) && luacheck lua/'

# Format code
format:
	@stylua lua/ spec/

# Check formatting
check:
	@stylua --check lua/ spec/

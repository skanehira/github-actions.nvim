.PHONY: test test-file lint format check install-deps install-parser dev

# Setup nvim-treesitter for tests
install-parser:
	@echo "Setting up nvim-treesitter..."
	@if [ ! -d deps/nvim-treesitter ]; then \
		git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter deps/nvim-treesitter; \
		echo "✓ nvim-treesitter cloned"; \
	else \
		echo "✓ nvim-treesitter already exists"; \
	fi

# Install test dependencies
install-deps: install-parser
	@echo "✓ Test dependencies ready"

# Run tests
test: install-deps
	eval $$(./luarocks path --no-bin) && ./luarocks test

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/parser_spec.lua"; \
		exit 1; \
	fi
	./luarocks busted $(FILE)

# Run linter
lint:
	eval $$(./luarocks path) && luacheck lua/

# Format code
format:
	@stylua lua/ spec/

# Check formatting
check:
	@stylua --check lua/ spec/

# Run development environment
dev: install-deps
	@echo "Starting development environment..."
	@echo "Opening test workflow file..."
	nvim -u dev.lua .github/workflows/test.yml

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    ca-certificates \
    neovim \
    luajit \
    libluajit-5.1-dev \
    pkg-config \
    unzip \
    luarocks \
    lua-busted \
    lua-filesystem \
    lua-penlight \
    lua-cliargs \
    lua-dkjson \
    lua-say \
    lua-luassert \
    lua-term \
    lua-mediator \
    lua-system \
    lua5.1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY . .

RUN mkdir -p /workspace/lua_modules \ 
    && luarocks install --tree /workspace/lua_modules --only-deps --deps-mode=all github-actions.nvim-scm-1.rockspec \ 
    && luarocks install --tree /workspace/lua_modules nlua \ 
    && luarocks install --tree /workspace/lua_modules busted \ 
    && ( [ -d deps/nvim-treesitter ] || git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter deps/nvim-treesitter )

CMD ["scripts/test/run.sh"]

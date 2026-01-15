FROM ubuntu:noble AS base

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y curl ca-certificates gnupg build-essential python3 && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm node-gyp

WORKDIR /app
COPY . /app

RUN pnpm install --frozen-lockfile

RUN chmod +x src/bin/index.cjs
RUN chmod +x src/bin/bots/*

CMD ["node", "/app/src/bin/bots/randomizer.cjs"] 

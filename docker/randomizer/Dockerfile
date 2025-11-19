FROM node:24-bookworm AS base

RUN apt update && apt upgrade -y
RUN apt install build-essential;
RUN npm install -g pnpm
RUN npm install -g node-gyp

WORKDIR /app
COPY . /app

RUN pnpm install --frozen-lockfile

RUN chmod +x src/bin/index.cjs
RUN chmod +x src/bin/bots/*

CMD ["node", "/app/src/bin/bots/randomizer.cjs"] 

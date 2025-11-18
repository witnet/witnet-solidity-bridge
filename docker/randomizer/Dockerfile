FROM node:24-alpine AS base

WORKDIR /app

RUN npm install -g pnpm

COPY migrations/ /app/migrations
COPY scripts/ /app/scripts
COPY src/ /app/src
COPY .no-postinstall /app
COPY hardhat.config.js /app
COPY package.json /app
COPY truffle-config.cjs /app
COPY tsconfig.json /app
COPY pnpm-lock.yaml /app

RUN pnpm install --frozen-lockfile

CMD ["node", "/app/src/bin/bots/randomizer.cjs"] 

FROM node:24-alpine AS base

WORKDIR /app

RUN corepack enable pnpm

COPY . .

RUN pnpm install --frozen-lockfile --prod

CMD ["node", "/app/src/bin/bots/randomizer.cjs"] 

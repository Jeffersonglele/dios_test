FROM node:20-alpine

WORKDIR /app

ARG DATABASE_URL="postgresql://postgres:placeholder@localhost:5432/dios_delices?schema=public"

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY prisma.config.ts ./
RUN DATABASE_URL=${DATABASE_URL} npx prisma generate
RUN npm prune --omit=dev

COPY src ./src

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "src/server.js"]

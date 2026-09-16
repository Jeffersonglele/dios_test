FROM node:20-alpine

WORKDIR /app

ARG DATABASE_URL="postgresql://postgres:placeholder@localhost:5432/dios_delices?schema=public"

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY prisma.config.ts ./
RUN DATABASE_URL=${DATABASE_URL} npx prisma generate
RUN npm prune --omit=dev
# Prisma CLI is needed at runtime to apply migrations on Render's free plan.
RUN npm install --no-save --omit=dev prisma@6.19.2

COPY src ./src
COPY docker-start.sh ./docker-start.sh

ENV NODE_ENV=production
EXPOSE 3000

CMD ["sh", "./docker-start.sh"]

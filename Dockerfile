FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npx prisma generate
RUN npm prune --omit=dev

COPY src ./src

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "src/server.js"]

# ================================
# Stage 1: Build
# ================================
FROM node:22-slim AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

# ================================
# Stage 2: Production
# ================================
FROM node:22-slim

WORKDIR /app

ENV NODE_ENV=production

COPY --chown=node:node --from=builder /app /app

USER node

EXPOSE 8000

CMD ["node", "index.js"]

# ================================
# Stage 1: Build
# ================================
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

# ================================
# Stage 2: Production
# ================================
FROM gcr.io/distroless/nodejs22-debian12

WORKDIR /app

COPY --from=builder /app /app

EXPOSE 8000

CMD ["index.js"]
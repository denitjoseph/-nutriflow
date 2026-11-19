# ==========================================
# Stage 1: Build React/Vite application
# ==========================================
FROM node:22-slim AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL

RUN npm run build

# ==========================================
# Stage 2: Production Nginx server
# ==========================================
FROM nginx:alpine-slim

# Prepare permissions for non-root execution
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid /var/cache/nginx /usr/share/nginx/html /etc/nginx/conf.d

COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html

COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

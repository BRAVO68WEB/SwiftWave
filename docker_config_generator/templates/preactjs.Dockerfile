# Install dependencies only when needed
FROM node:18.11-slim AS deps
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Builder stage
FROM node:18-alpine AS builder

# Build args
ARG BUILD_COMMAND="npm run build"

WORKDIR /app
COPY . .
COPY --from=deps /app/node_modules ./node_modules
ENV NODE_ENV production
RUN ${BUILD_COMMAND} && npm prune --production

# Runtime stage
FROM nginx:stable-bullseye

# Build args
ARG BUILD_DIRECTORY=build

COPY --from=builder /app/${BUILD_DIRECTORY} /usr/share/nginx/html

# Modify nginx file permissions
RUN chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

EXPOSE 80
ENV PORT 80
CMD ["nginx", "-g", "daemon off;"]

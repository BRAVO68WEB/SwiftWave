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

# Rebuild the source code only when needed
FROM node:18.11-slim AS builder

# Build args
ARG BUILD_COMMAND="npm run build"

WORKDIR /app
COPY . .
COPY --from=deps /app/node_modules ./node_modules
RUN touch ./modify.js
RUN echo 'let data = require("./next.config.js");' >> ./modify.js
RUN echo 'data.output = "standalone";' >> ./modify.js
RUN echo 'require("fs").writeFileSync("./next.config.js", `module.exports = ${JSON.stringify(data, null, 4)}`);'  >> ./modify.js
RUN node ./modify.js
RUN rm ./modify.js
ENV NODE_ENV production
RUN ${BUILD_COMMAND} && npm prune --production

# Production image, copy all the files and run next
FROM node:18.11-slim AS runner

# Build args
ARG PORT="80"

WORKDIR /app
ENV NODE_ENV production
RUN addgroup --gid 1001 nodejs
RUN adduser --disabled-password --gecos "" --uid 1001 --ingroup nodejs nextjs
COPY --from=builder /app/next.config.js ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./        
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE ${PORT}
ENV PORT ${PORT}
CMD ["node", "server.js"]
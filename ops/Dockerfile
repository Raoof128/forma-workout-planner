# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim@sha256:d6aa754f16b3197301076f047b5def2f02ea1dbbc2ca920407d46d7ec7f87b20 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=secret,id=proxy_ca,required=false \
    if [ -s /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi \
    && npm ci --strict-ssl=true --no-audit --no-fund --maxsockets=5 --fetch-retries=5
COPY server ./server
COPY src/data.js src/storage.js src/exerciseMetrics.js ./src/
COPY src/catalog/exercises.json ./src/catalog/exercises.json
COPY tsconfig.json tsconfig.server.json ./
RUN npm run build:server \
    && npm prune --omit=dev --offline --strict-ssl=true --no-audit --no-fund \
    && npm cache clean --force

FROM node:24-bookworm-slim@sha256:d6aa754f16b3197301076f047b5def2f02ea1dbbc2ca920407d46d7ec7f87b20 AS runtime
ENV NODE_ENV=production PORT=3000
WORKDIR /app
RUN groupadd --system --gid 10001 forma \
    && useradd --system --uid 10001 --gid forma --home-dir /nonexistent --shell /usr/sbin/nologin forma
COPY --from=build --chown=forma:forma /app/package.json /app/package-lock.json ./
COPY --from=build --chown=forma:forma /app/node_modules ./node_modules
COPY --from=build --chown=forma:forma /app/build/server ./build/server
COPY --from=build --chown=forma:forma /app/build/src ./build/src
USER forma
EXPOSE 3000
CMD ["node", "build/server/index.js"]

FROM node:22-bookworm-slim AS web
WORKDIR /web
COPY apps/web/package*.json ./
RUN npm ci
COPY apps/web/ ./
RUN npm run build

FROM elixir:1.18.4-otp-27-slim AS build
ENV MIX_ENV=prod
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates build-essential git && rm -rf /var/lib/apt/lists/*
RUN mix local.hex --force && mix local.rebar --force
COPY apps/api/mix.exs apps/api/mix.lock ./
COPY apps/api/config/ config/
RUN mix deps.get --only prod && mix deps.compile
COPY apps/api/lib/ lib/
COPY --from=web /web/dist/ priv/static/
RUN mix compile --warnings-as-errors && mix release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssl libstdc++6 libncurses6 ca-certificates curl && rm -rf /var/lib/apt/lists/* && useradd --system --uid 10001 gcf
WORKDIR /app
COPY --from=build --chown=gcf:gcf /app/_build/prod/rel/gcf ./
USER gcf
ENV PORT=4000 LANG=C.UTF-8
EXPOSE 4000
HEALTHCHECK --interval=20s --timeout=5s --start-period=15s CMD curl -fsS http://localhost:4000/healthz || exit 1
CMD ["bin/gcf", "start"]

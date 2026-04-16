FROM hexpm/elixir:1.17.3-erlang-27.1-debian-bookworm-20240812 AS build

RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS app

RUN apt-get update -y && apt-get install -y --no-install-recommends \
  ca-certificates \
  libstdc++6 \
  openssl \
  libncurses5 \
  sqlite3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/_build/prod/rel/w_core ./

ENV HOME=/app
ENV MIX_ENV=prod
ENV DATABASE_PATH=/var/lib/w_core/w_core_prod.db
ENV PHX_HOST=localhost
ENV PORT=4000

VOLUME ["/var/lib/w_core"]

EXPOSE 4000

CMD ["/bin/sh", "-c", "/app/bin/w_core eval \"WCore.Release.migrate\" && /app/bin/w_core start"]

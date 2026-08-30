# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV TAR_OPTIONS=--no-same-owner

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    libglu1-mesa \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app

COPY pubspec.yaml ./
RUN flutter config --enable-web && flutter pub get

COPY . .
RUN flutter build web --release --pwa-strategy=none

FROM python:3.12-slim AS runtime

WORKDIR /app
COPY --from=build /app/build/web /app/build/web
COPY server.py /app/server.py
COPY data/seed_orders.json /app/seed_orders.json

ENV PORT=10000
ENV DATA_DIR=/app/data
EXPOSE 10000

CMD ["python", "/app/server.py"]

# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

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
RUN flutter build web --release

FROM python:3.12-slim AS runtime

WORKDIR /app
COPY --from=build /app/build/web /app

ENV PORT=10000
EXPOSE 10000

CMD ["sh", "-c", "python -m http.server ${PORT:-10000} --bind 0.0.0.0 -d /app"]

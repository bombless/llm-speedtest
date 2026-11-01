# syntax=docker/dockerfile:1.7
# Multi-stage build: web UI (node) -> cross-compiled Go binary -> distroless runtime.

FROM --platform=$BUILDPLATFORM node:22-alpine AS web
WORKDIR /src/web
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build

FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS build
ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev
ARG COMMIT=none
ARG DATE=unknown
WORKDIR /src
ENV CGO_ENABLED=0 GOFLAGS=-trimpath GOTOOLCHAIN=auto
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=web /src/web/dist ./web/dist
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build \
      -ldflags "-s -w -X github.com/AnnaofArendelle/llm-speedtest/internal/version.Version=$VERSION -X github.com/AnnaofArendelle/llm-speedtest/internal/version.Commit=$COMMIT -X github.com/AnnaofArendelle/llm-speedtest/internal/version.Date=$DATE" \
      -o /out/llm-speedtest ./cmd/llm-speedtest

FROM gcr.io/distroless/static-debian12:nonroot
LABEL org.opencontainers.image.source="https://github.com/AnnaofArendelle/llm-speedtest" \
      org.opencontainers.image.description="Availability, latency, load, capability and quality benchmarks for OpenAI-compatible LLM APIs" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
COPY --from=build /out/llm-speedtest /llm-speedtest
VOLUME ["/data"]
EXPOSE 8787
ENTRYPOINT ["/llm-speedtest"]
CMD ["serve", "--listen", "0.0.0.0:8787", "--data-dir", "/data"]

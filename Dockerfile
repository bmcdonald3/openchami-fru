FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.* ./
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 go build -o /ochami-fru

FROM chainguard/wolfi-base:latest

RUN set -ex && apk update && apk add --no-cache tini && rm -rf /var/cache/apk/*

ENV SMD_HOST="smd"
ENV API_SERVER_PORT=":8080"

COPY --from=builder /ochami-fru /usr/local/bin/

USER 65534:65534

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/ochami-fru"]
FROM chainguard/wolfi-base:latest

# Include curl in the final image.
RUN set -ex \
    && apk update \
    && apk add --no-cache --no-check-certificate curl tini \
    && rm -rf /var/cache/apk/*  \
    && rm -rf /tmp/*

COPY go.* ./
COPY *.go ./

# nobody 65534:65534
USER 65534:65534

CMD [ "/openchami-fru" ]

ENTRYPOINT [ "/sbin/tini", "--" ]
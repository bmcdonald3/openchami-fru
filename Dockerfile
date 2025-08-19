FROM chainguard/wolfi-base:latest

RUN set -ex && apk update && apk add --no-cache --no-check-certificate tini && rm -rf /var/cache/apk/*

COPY ochami-fru /usr/local/bin/ochami-fru

USER 65534

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/ochami-fru"]
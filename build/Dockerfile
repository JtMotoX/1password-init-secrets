FROM alpine:latest

RUN apk add --no-cache gettext curl diffutils

COPY --chmod=755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

FROM alpine:edge

RUN \
echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
apk update && \
apk add cfssl && \
adduser -D cfssl

COPY entrypoint.sh /
USER cfssl:cfssl
WORKDIR /home/cfssl
ENTRYPOINT ["/entrypoint.sh"]

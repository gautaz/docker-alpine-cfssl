FROM alpine:3.6 as builder

ENV PATH /go/bin:/usr/local/go/bin:$PATH
ENV GOPATH /go
ENV USER root

RUN \
apk update && \
apk upgrade && \
apk add git go musl-dev && \
mkdir -p /go/src/github.com/cloudflare && \
cd /go/src/github.com/cloudflare && \
git clone https://github.com/cloudflare/cfssl.git && \
cd cfssl && \
go build -o /go/bin/cfssl ./cmd/cfssl && \
go build -o /go/bin/cfssljson ./cmd/cfssljson && \
go build -o /go/bin/mkbundle ./cmd/mkbundle && \
go build -o /go/bin/multirootca ./cmd/multirootca


FROM alpine:3.6

RUN \
apk update && \
apk upgrade && \
adduser -D cfssl

COPY --from=builder /go/bin/cfssl /usr/bin
COPY --from=builder /go/bin/cfssljson /usr/bin
COPY --from=builder /go/bin/mkbundle /usr/bin
COPY --from=builder /go/bin/multirootca /usr/bin
COPY --from=builder /go/src/github.com/cloudflare/cfssl/certdb/mysql /usr/share/misc/cfssl/mysql
COPY --from=builder /go/src/github.com/cloudflare/cfssl/certdb/pg /usr/share/misc/cfssl/pg
COPY --from=builder /go/src/github.com/cloudflare/cfssl/certdb/sqlite /usr/share/misc/cfssl/sqlite

COPY entrypoint.sh /
USER cfssl:cfssl
WORKDIR /home/cfssl
ENTRYPOINT ["/entrypoint.sh"]

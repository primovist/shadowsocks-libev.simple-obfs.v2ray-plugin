FROM golang:alpine AS builder
RUN set -ex \
	&& apk add --no-cache git build-base \
	&& mkdir -p /go/src/github.com/shadowsocks \
	&& cd /go/src/github.com/shadowsocks \
	&& git clone https://github.com/shadowsocks/v2ray-plugin.git \
	&& cd v2ray-plugin \
	&& go get -d \
	&& go build -o /go/bin/v2ray-plugin

FROM alpine:latest
LABEL maintainer="Primovist"

RUN runDeps="\
		git \
		build-base \
		c-ares-dev \
		autoconf \
		automake \
		libev-dev \
		libtool \
		libsodium-dev \
		linux-headers \
		mbedtls-dev \
		pcre-dev \
	"; \
	set -ex \
	&& apk add --no-cache --virtual .build-deps ${runDeps} \
	&& mkdir -p /tmp/obfs \
	&& cd /tmp/obfs \
	&& git clone --depth=1 https://github.com/shadowsocks/simple-obfs.git . \
	&& git submodule update --init --recursive \
	&& ./autogen.sh \
	&& ./configure --prefix=/usr --disable-documentation \
	&& make install \
	&& mkdir -p /tmp/libev \
	&& cd /tmp/libev \
	&& git clone --depth=1 https://github.com/shadowsocks/shadowsocks-libev.git . \
	&& git submodule update --init --recursive \
	&& ./autogen.sh \
	&& ./configure --prefix=/usr --disable-documentation \
	&& make install \
	&& apk add --no-cache \
		tzdata \
		rng-tools \
		ca-certificates \
		$(scanelf --needed --nobanner /usr/bin/ss-* \
		| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
		| xargs -r apk info --installed \
		| sort -u) \
	&& apk del .build-deps \
	&& cd /tmp \
	&& rm -rf /tmp/obfs /tmp/libev

COPY --from=builder /go/bin/v2ray-plugin /usr/bin
COPY config.json /etc/shadowsocks-libev/config.json
VOLUME /etc/shadowsocks-libev

ENV TZ=Asia/Shanghai

CMD [ "ss-server", "-c", "/etc/shadowsocks-libev/config.json" ]

FROM alpine:3.6

# install for 'bash', 'curl', 'make' command
RUN apk add --no-cache bash curl alpine-sdk


# mumoshu/dcind
## https://github.com/mumoshu/dcind/blob/master/Dockerfile
#
ENV DOCKER_VERSION=1.11.1 \
    DOCKER_COMPOSE_VERSION=1.7.1 \
    ENTRYKIT_VERSION=0.4.0

# Install Docker, Docker Compose
RUN apk --update --no-cache \
        add curl device-mapper mkinitfs zsh e2fsprogs e2fsprogs-extra iptables && \
        curl https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz | tar zx && \
        mv /docker/* /bin/ && chmod +x /bin/docker* \
    && \
        apk add py-pip && \
        pip install docker-compose==${DOCKER_COMPOSE_VERSION} \
    && \
        apk add --no-cache openssl \
        && wget https://github.com/progrium/entrykit/releases/download/v${ENTRYKIT_VERSION}/entrykit_${ENTRYKIT_VERSION}_Linux_x86_64.tgz \
        && tar -xvzf entrykit_${ENTRYKIT_VERSION}_Linux_x86_64.tgz \
        && rm entrykit_${ENTRYKIT_VERSION}_Linux_x86_64.tgz \
        && mv entrykit /bin/entrykit \
        && chmod +x /bin/entrykit \
        && entrykit --symlink

# COPY ./entrykit /bin/entrykit

# RUN chmod +x /bin/entrykit && entrykit --symlink

# COPY ./docker-compose.yml /src/

WORKDIR /src

RUN echo $'#!/bin/zsh \n\
/bin/docker daemon' > /bin/docker-daemon && chmod +x /bin/docker-daemon

RUN echo $'#!/bin/zsh \n\
docker info && \n\
/usr/bin/docker-compose pull && \n\
echo Cloning /var/lib/docker to /cached-graph... && \n\
ls -lah /var/lib/docker' > /bin/docker-compose-pull && chmod +x /bin/docker-compose-pull

# ENV PREHOOK_PRINT=cat\ /src/docker-compose.yml
ENV SWITCH_PULL="codep docker-daemon docker-compose-pull"
ENV SWITCH_SHELL=zsh
ENV CODEP_DAEMON=/bin/docker\ daemon
ENV CODEP_COMPOSE=/usr/bin/docker-compose\ up

# Include useful functions to start/stop docker daemon in garden-runc containers on Concourse CI
# Its usage would be something like: source /docker.lib.sh && start_docker "" "" "-g=$(pwd)/graph"
COPY dcind/docker-lib.sh /docker-lib.sh

# golang
## ref https://github.com/docker-library/golang/blob/cffcff7fce7f6b6b5c82fc8f7b3331a10590a661/1.8/alpine3.6/Dockerfile
#
RUN apk add --no-cache ca-certificates

ENV GOLANG_VERSION 1.8.5

# https://golang.org/issue/14851 (Go 1.8 & 1.7)
# https://golang.org/issue/17847 (Go 1.7)
# COPY *.patch /go-alpine-patches/
COPY golang/*.patch /go-alpine-patches/

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
		openssl \
		go \
	; \
	export \
# set GOROOT_BOOTSTRAP such that we can actually build Go
		GOROOT_BOOTSTRAP="$(go env GOROOT)" \
# ... and set "cross-building" related vars to the installed system's values so that we create a build targeting the proper arch
# (for example, if our build host is GOARCH=amd64, but our build env/image is GOARCH=386, our build needs GOARCH=386)
		GOOS="$(go env GOOS)" \
		GOARCH="$(go env GOARCH)" \
		GO386="$(go env GO386)" \
		GOARM="$(go env GOARM)" \
		GOHOSTOS="$(go env GOHOSTOS)" \
		GOHOSTARCH="$(go env GOHOSTARCH)" \
	; \
	\
	wget -O go.tgz "https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz"; \
	echo '4949fd1a5a4954eb54dd208f2f412e720e23f32c91203116bed0387cf5d0ff2d *go.tgz' | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	cd /usr/local/go/src; \
	for p in /go-alpine-patches/*.patch; do \
		[ -f "$p" ] || continue; \
		patch -p2 -i "$p"; \
	done; \
	./make.bash; \
	\
	rm -rf /go-alpine-patches; \
	apk del .build-deps; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# COPY go-wrapper /usr/local/bin/
COPY golang/go-wrapper /usr/local/bin/

# aws cli
## ref https://github.com/jensendw/concourse-aws-cli/blob/master/Dockerfile
#
# LABEL Name="concourse-aws-cli"
# LABEL Version="0.2"
RUN apk update && apk add python py-pip
RUN pip install awscli==1.11.168 --upgrade
EXPOSE 0

CMD []

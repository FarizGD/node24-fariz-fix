FROM node:24-trixie-slim AS guest

LABEL       author="Michael Parker" maintainer="parker@pterodactyl.io"

# install packages + sudo
RUN         apt update \
            && apt -y install \
                sudo \
                ffmpeg \
                iproute2 \
                git \
                sqlite3 \
                libsqlite3-dev \
                python3 \
                python3-dev \
                ca-certificates \
                dnsutils \
                tzdata \
                zip \
                tar \
                curl \
                build-essential \
                libtool \
                iputils-ping \
                libnss3 \
                tini \
            && rm -rf /var/lib/apt/lists/*


RUN npm install --global npm@latest typescript ts-node @types/node tsx corepack \
    && corepack enable \
    && corepack prepare pnpm@latest --activate
# Package scripts must not try to start services in the guest.
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod 755 /usr/sbin/policy-rc.d \
    && printf 'APT::Sandbox::User "root";\n' > /etc/apt/apt.conf.d/99proot \
    && mkdir -p /home/container \
    && tar --exclude=./proc --exclude=./sys --exclude=./dev \
        --exclude=./tmp --exclude=./run --exclude=./etc/hostname \
        --exclude=./etc/hosts --exclude=./etc/resolv.conf \
        -C / -cpf /tmp/debian-rootfs.tar .

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        proot tini ca-certificates iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -d /home/container -s /bin/bash container
COPY --from=guest /tmp/debian-rootfs.tar /opt/debian-rootfs.tar
COPY --chmod=755 entrypoint.sh /entrypoint.sh
USER container
ENV HOME=/home/container USER=container
WORKDIR /home/container
STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/entrypoint.sh"]

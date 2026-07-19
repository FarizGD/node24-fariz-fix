FROM        --platform=$TARGETOS/$TARGETARCH node:24-trixie-slim

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

# create container user
RUN         useradd -m -d /home/container -s /bin/bash container \
            && usermod -aG sudo container \
            && echo "container ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/container \
            && chmod 0440 /etc/sudoers.d/container

STOPSIGNAL SIGINT

# install global npm packages
RUN         npm install --global npm@latest typescript ts-node @types/node tsx

# install pnpm
RUN         npm install -g corepack \
            && corepack enable \
            && corepack prepare pnpm@latest --activate

# setup user environment
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        --chown=container:container ./../entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh

ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]

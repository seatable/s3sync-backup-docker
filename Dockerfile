ARG BASE_IMAGE="debian:12.8-slim@sha256:1537a6a1cbc4b4fd401da800ee9480207e7dc1f23560c21259f681db56768f63"

FROM ${BASE_IMAGE} AS build-image

ARG RCLONE_VERSION="v1.71.0"

RUN apt-get update && apt-get install --no-install-recommends -y \
unzip \
bzip2 \
curl

# Get rclone binary
ADD https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip /
RUN unzip rclone-${RCLONE_VERSION}-linux-amd64.zip && mv rclone-*-linux-amd64/rclone /bin/rclone

# Get docker binary 
ADD https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz /
RUN tar --extract --file docker-${DOCKER_VERSION}.tgz --directory /tmp/ --strip-components 1

FROM ${BASE_IMAGE} AS runtime-image

RUN \
    apt-get update \
    && apt-get install --no-install-recommends -y \
        curl \
        openssl \
        mailutils \
        msmtp \
        tree \
        fuse \
        cron \
        ca-certificates \
        gzip \
        jq \
        openssh-client \
    && apt-get clean

# get rclone and docker from build-image
COPY --from=build-image /bin/rclone /bin/rclone
COPY --from=build-image /tmp/docker /usr/local/bin/docker

RUN mkdir -p /local /var/log/rclone \
    && touch /var/log/cron.log \
    && touch /var/log/rclone/backup.log \
    && touch /var/log/rclone/lastrun.log \
    && chmod +x /bin/rclone /usr/local/bin/docker

# /data is the dir where you have to put the data to be backed up
VOLUME /data

COPY backup.sh /bin/backup
COPY entry.sh /bin/entry.sh
COPY log.sh /bin/log.sh
RUN chmod +x /bin/backup /bin/entry.sh /bin/log.sh

ENTRYPOINT ["/bin/entry.sh"]
CMD ["cron", "-f", "-L", "2"]

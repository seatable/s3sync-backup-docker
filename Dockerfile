FROM alpine:latest

RUN apk add --no-cache curl bash cronie unzip jq tzdata

# Get newest rclone version
RUN curl -Of https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip -q rclone-current-linux-amd64.zip && \
    mv rclone-*-linux-amd64/rclone /usr/bin/ && \
    chmod 755 /usr/bin/rclone && \
    rm -r rclone-*-linux-amd64 rclone-current-linux-amd64.zip

# Preparation of s3sync script
COPY sync.sh /bin/sync.sh
RUN chmod +x /bin/sync.sh

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
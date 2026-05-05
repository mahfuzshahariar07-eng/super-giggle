FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    socat \
    ncat \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://tailscale.com/install.sh | sh

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 2711

CMD ["/start.sh"]

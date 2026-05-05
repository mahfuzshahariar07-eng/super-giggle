FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    python3 \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://tailscale.com/install.sh | sh

COPY start.sh /start.sh
COPY proxy.py /proxy.py

RUN chmod +x /start.sh /proxy.py

EXPOSE 2711

CMD ["/start.sh"]

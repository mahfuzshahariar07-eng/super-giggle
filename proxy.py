#!/usr/bin/env python3

import os
import socket
import struct
import threading
import selectors
import ipaddress

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "2711"))

SOCKS_HOST = "127.0.0.1"
SOCKS_PORT = 1055

TARGET_HOST = os.environ["TARGET_HOST"]
TARGET_PORT = int(os.environ["TARGET_PORT"])


def recv_exact(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise ConnectionError("socket closed")
        data += chunk
    return data


def socks5_connect(host, port):
    s = socket.create_connection((SOCKS_HOST, SOCKS_PORT), timeout=20)
    s.settimeout(None)

    # SOCKS5 greeting: version 5, one method, no-auth
    s.sendall(b"\x05\x01\x00")
    resp = recv_exact(s, 2)

    if resp != b"\x05\x00":
        raise ConnectionError(f"SOCKS5 auth failed: {resp!r}")

    try:
        ip = ipaddress.ip_address(host)

        if ip.version == 4:
            atyp = b"\x01"
            addr = socket.inet_aton(host)
        else:
            atyp = b"\x04"
            addr = socket.inet_pton(socket.AF_INET6, host)

    except ValueError:
        encoded = host.encode("utf-8")

        if len(encoded) > 255:
            raise ValueError("Target hostname is too long for SOCKS5")

        atyp = b"\x03"
        addr = bytes([len(encoded)]) + encoded

    req = b"\x05\x01\x00" + atyp + addr + struct.pack("!H", port)
    s.sendall(req)

    header = recv_exact(s, 4)

    if header[0] != 5:
        raise ConnectionError(f"Invalid SOCKS5 response: {header!r}")

    if header[1] != 0:
        raise ConnectionError(f"SOCKS5 connect failed, code={header[1]}")

    bind_atyp = header[3]

    if bind_atyp == 1:
        recv_exact(s, 4)
    elif bind_atyp == 3:
        ln = recv_exact(s, 1)[0]
        recv_exact(s, ln)
    elif bind_atyp == 4:
        recv_exact(s, 16)
    else:
        raise ConnectionError(f"Invalid SOCKS5 address type: {bind_atyp}")

    recv_exact(s, 2)

    return s


def forward(client, remote):
    selector = selectors.DefaultSelector()

    try:
        selector.register(client, selectors.EVENT_READ, remote)
        selector.register(remote, selectors.EVENT_READ, client)

        while True:
            events = selector.select()

            for key, _ in events:
                src = key.fileobj
                dst = key.data

                data = src.recv(65536)

                if not data:
                    return

                dst.sendall(data)

    finally:
        try:
            selector.close()
        except Exception:
            pass

        try:
            client.close()
        except Exception:
            pass

        try:
            remote.close()
        except Exception:
            pass


def handle_client(client, addr):
    print(f"Accepted connection from {addr}", flush=True)

    try:
        remote = socks5_connect(TARGET_HOST, TARGET_PORT)
        print(f"Connected to target {TARGET_HOST}:{TARGET_PORT}", flush=True)
        forward(client, remote)

    except Exception as e:
        print(f"Connection error from {addr}: {e}", flush=True)

        try:
            client.close()
        except Exception:
            pass


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_HOST, LISTEN_PORT))
    server.listen(128)

    print(f"Listening on {LISTEN_HOST}:{LISTEN_PORT}", flush=True)

    while True:
        client, addr = server.accept()
        thread = threading.Thread(
            target=handle_client,
            args=(client, addr),
            daemon=True
        )
        thread.start()


if __name__ == "__main__":
    main()

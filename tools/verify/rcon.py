"""Minimal Source RCON client for the runtime verification harness."""
import socket, struct


class Rcon:
    def __init__(self, host, port, password, timeout=120):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.request_id = 0
        self._send(3, password)
        self._recv()

    def _send(self, packet_type, body):
        self.request_id += 1
        payload = struct.pack("<ii", self.request_id, packet_type) + body.encode() + b"\x00\x00"
        self.sock.sendall(struct.pack("<i", len(payload)) + payload)

    def _recv(self):
        length = struct.unpack("<i", self.sock.recv(4))[0]
        data = b""
        while len(data) < length:
            data += self.sock.recv(length - len(data))
        return data[8:-2].decode(errors="replace")

    def cmd(self, command):
        self._send(2, command)
        return self._recv()

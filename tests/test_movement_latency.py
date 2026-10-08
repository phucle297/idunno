"""Exercise jitter with real UDP packets, not a mocked scheduler."""
import socket
import time
import unittest

from run_movement_latency_test import DelayProxy


class DelayProxyTest(unittest.TestCase):
    def test_loss_is_deterministic_in_both_udp_directions(self):
        for repeat in range(2):
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                server.bind(('127.0.0.1', 0))
                server.settimeout(.1)
                client.settimeout(.1)
                proxy = DelayProxy(server.getsockname()[1], 0, loss_every=3)
                try:
                    for index in range(1, 7):
                        client.sendto(str(index).encode(), proxy.front.getsockname())
                    received = []
                    address = None
                    while True:
                        try:
                            data, address = server.recvfrom(1024)
                            received.append(data)
                        except socket.timeout:
                            break
                    self.assertEqual(received, [b'1', b'2', b'4', b'5'])
                    for index in range(1, 7):
                        server.sendto(str(index).encode(), address)
                    received = []
                    while True:
                        try:
                            received.append(client.recvfrom(1024)[0])
                        except socket.timeout:
                            break
                    self.assertEqual(received, [b'1', b'2', b'4', b'5'])
                    self.assertEqual(proxy.received_counts, [6, 6])
                    self.assertEqual(proxy.dropped_counts, [2, 2])
                    self.assertEqual(proxy.counts, [4, 4])
                    self.assertIsNone(proxy.error)
                finally:
                    proxy.close()

    def test_jitter_holds_both_directions_and_preserves_payloads(self):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            server.bind(('127.0.0.1', 0))
            server.settimeout(2)
            client.settimeout(2)
            proxy = DelayProxy(server.getsockname()[1], 200, jitter_ms=30)
            try:
                for index in range(3):
                    payload = f'packet-{index}'.encode()
                    started = time.monotonic()
                    client.sendto(payload, proxy.front.getsockname())
                    received, address = server.recvfrom(1024)
                    self.assertEqual(received, payload)
                    server.sendto(received, address)
                    self.assertEqual(client.recvfrom(1024)[0], payload)
                    self.assertGreaterEqual(time.monotonic() - started, .139)
                # recvfrom can wake us before the relay updates its post-send
                # counters. Wait for bookkeeping, not for a looser packet gate.
                deadline = time.monotonic() + 1
                while proxy.counts != [3, 3] and time.monotonic() < deadline:
                    time.sleep(.001)
                self.assertEqual(proxy.counts, [3, 3])
                self.assertEqual(sorted(proxy.scheduled_holds), [70, 70, 100, 100, 130, 130])
                self.assertIsNone(proxy.error)
            finally:
                proxy.close()


if __name__ == '__main__':
    unittest.main()

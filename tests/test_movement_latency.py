"""Exercise jitter with real UDP packets, not a mocked scheduler."""
import socket
import time
import unittest

from run_movement_latency_test import DelayProxy


class DelayProxyTest(unittest.TestCase):
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
                self.assertEqual(proxy.counts, [3, 3])
                self.assertEqual(sorted(proxy.scheduled_holds), [70, 70, 100, 100, 130, 130])
                self.assertIsNone(proxy.error)
            finally:
                proxy.close()


if __name__ == '__main__':
    unittest.main()

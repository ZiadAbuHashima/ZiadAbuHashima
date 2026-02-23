"""
Simple concurrent TCP port scanner

Usage:
  python portz.py example.com 1 1024 --timeout 0.5 --threads 100

This script scans a range of ports on a target host and prints open ports.
"""
from __future__ import annotations

import argparse
import socket
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List


def scan_port(host: str, port: int, timeout: float) -> int | None:
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	s.settimeout(timeout)
	try:
		result = s.connect_ex((host, port))
		if result == 0:
			return port
	except Exception:
		return None
	finally:
		try:
			s.close()
		except Exception:
			pass
	return None


def scan_range(host: str, ports: List[int], timeout: float, workers: int) -> List[int]:
	open_ports: List[int] = []
	with ThreadPoolExecutor(max_workers=workers) as ex:
		futures = {ex.submit(scan_port, host, p, timeout): p for p in ports}
		for fut in as_completed(futures):
			port = fut.result()
			if port:
				open_ports.append(port)
	return sorted(open_ports)


def parse_args() -> argparse.Namespace:
	p = argparse.ArgumentParser(description="Simple concurrent TCP port scanner")
	p.add_argument("host", help="Hostname or IP to scan")
	p.add_argument("start", type=int, help="Start port (inclusive)")
	p.add_argument("end", type=int, help="End port (inclusive)")
	p.add_argument("--timeout", type=float, default=0.5, help="Socket timeout in seconds")
	p.add_argument("--threads", type=int, default=100, help="Number of parallel threads")
	return p.parse_args()


def main() -> None:
	args = parse_args()
	try:
		target_ip = socket.gethostbyname(args.host)
	except socket.gaierror:
		print("Could not resolve host:", args.host)
		return

	start = max(1, min(65535, args.start))
	end = max(1, min(65535, args.end))
	if start > end:
		start, end = end, start

	ports = list(range(start, end + 1))
	print(f"Scanning {args.host} ({target_ip}) ports {start}-{end} with {args.threads} threads...")
	open_ports = scan_range(target_ip, ports, args.timeout, args.threads)

	if open_ports:
		print("Open ports:")
		for p in open_ports:
			print(f" - {p}")
	else:
		print("No open ports found in range.")


if __name__ == "__main__":
	main()


#!/bin/sh
docker run --rm -v ./unbound.conf:/etc/unbound/unbound.conf -p 53:53/udp -p53:53/tcp alpinelinux/unbound

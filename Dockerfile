# Dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      iproute2 iputils-ping net-tools iperf3 traceroute tcpdump curl vim && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Mantém o container em modo interativo / shell
CMD ["/bin/bash"]


# Relatório Final — Experimento de Rede Docker

**Topologia: h1 ↔ roteador ↔ h2**


---

## 1. Descrição da topologia e das redes utilizadas

A topologia construída é simples e composta por três containers Docker:

- **h1** conectado à rede `rede1` (172.30.0.0/24)

- **roteador** com duas interfaces: uma em `rede1` e outra em `rede2`

- **h2** conectado à rede `rede2` (172.31.0.0/24)


**Endereçamento e gateway do roteador**:

- h1: `172.30.0.10/24`

- roteador (rede1): `172.30.0.254` (gateway da rede no cenário)

- roteador (rede2): `172.31.0.254` (gateway da outra rede)

- h2: `172.31.0.10/24`


Observação: os endereços finais `.254` foram escolhidos para evitar conflito com o IP `.1` reservado pelo Docker como gateway.


---

## 2. Configurações de roteamento realizadas nos três containers

As configurações foram realizadas com os seguintes comandos executados dentro dos containers:

### h1

```bash
ip route add 172.31.0.0/24 via 172.30.0.254
```

### h2

```bash
ip route add 172.30.0.0/24 via 172.31.0.254
```

### roteador

O roteador foi criado com `privileged: true` e o encaminhamento IPv4 habilitado via `sysctl`:

```bash
sysctl -w net.ipv4.ip_forward=1
```


Além disso, `h1` e `h2` receberam a capability `NET_ADMIN` para permitir a adição de rotas internamente.


---

## 3. Capturas de tela / saídas dos comandos verificando a conectividade

### Ping h1 → h2 (20 pacotes)

```
20 packets transmitted, 20 received, 0% loss
rtt min/avg/max/mdev = 0.067/0.168/0.190/0.027 ms
```

### Ping h1 → roteador (5 pacotes)

```
5 packets transmitted, 5 received, 0% loss
rtt min/avg/max/mdev = 0.052/0.112/0.158/0.035 ms
```

### Ping h2 → roteador (5 pacotes)

```
5 packets transmitted, 5 received, 0% loss
rtt min/avg/max/mdev = 0.055/0.121/0.143/0.033 ms
```

### Traceroute h1 → h2

```
1  172.30.0.254 (roteador)
2  172.31.0.10 (h2)
```

### Traceroute h2 → h1

```
1  172.31.0.254 (roteador)
2  172.30.0.10 (h1)
```


---

## 4. Resultados dos testes de desempenho (iperf3) e análise comparativa

### TCP — single stream (10s)

```
Transfer: 36.1 GBytes — Throughput médio: 31.0 Gbits/sec — Retransmissões: 0
```

### TCP — paralelismo (-P 4, 10s)

```
Transfer total (soma): 103 GBytes — Vazão agregada: 88.1 Gbits/sec — Retransmissões totais: 1959
```

### UDP — 10 Mbit/s (10s)

```
Transfer: 11.9 MBytes — Jitter: 0.011 ms — Perda: 0/8632 (0%)
```


**Análise comparativa:**

- O teste TCP single stream mostrou excelente throughput (31 Gbps), compatível com redes de alta velocidade em ambiente local com boa CPU.

- O teste com paralelismo aumentou a vazão agregada para 88.1 Gbps, porém com **1959 retransmissões**, indicando que aumentar demasiadamente o paralelismo levou a flutuações e perdas temporárias na pilha de rede ou no caminho (possível limitação de CPU, buffers ou congestionamento interno).

- O teste UDP a 10 Mbps apresentou **0% de perda** e jitter desprezível, confirmando boa qualidade para tráfego em tempo real em baixa taxa.


---

## 5. Discussão dos problemas encontrados durante a configuração

1. **Address already in use** ao subir os containers: causado por tentativa de atribuir o IP `.1` (gateway Docker) a um container. Solução: mover o IP do roteador para `.254` (172.30.0.254 / 172.31.0.254).

2. **RTNETLINK answers: Operation not permitted** ao adicionar rotas em h1/h2: solução foi dar `cap_add: NET_ADMIN` para os containers h1/h2.

3. **Retransmissões no teste TCP com paralelismo:** possível limitação do host ou do caminho no pico de uso; recomendado repetir testes com monitoramento de CPU e buffers.


---

## 6. Conclusões sobre o experimento

- A topologia implementada funcionou como esperado: o roteador estabeleceu comunicação entre redes distintas, e os hosts se comunicaram sem perda.

- As medições mostram alta performance em TCP e estabilidade em UDP nas condições testadas.

- Para relatórios mais completos, sugerimos testes de longa duração, monitoramento de recursos (CPU/RAM) durante os testes intensivos e experimentos com diferentes tamanhos de MTU e filas.


---

## 7. Apêndice — Saídas brutas (capturas)

### ip route (h1)

```
default via 172.30.0.1 dev eth0
172.30.0.0/24 dev eth0 proto kernel scope link src 172.30.0.10
172.31.0.0/24 via 172.30.0.254 dev eth0
```

### ip route (h2)

```
default via 172.31.0.1 dev eth0
172.30.0.0/24 via 172.31.0.254 dev eth0
172.31.0.0/24 dev eth0 proto kernel scope link src 172.31.0.10
```

### ip route (roteador)

```
default via 172.30.0.1 dev eth1
172.30.0.0/24 dev eth1 proto kernel scope link src 172.30.0.254
172.31.0.0/24 dev eth0 proto kernel scope link src 172.31.0.25
```

### ip addr (h1)

```
lo: 127.0.0.1/8
eth0: 172.30.0.10/24 MAC ca:da:6a:35:66:d4
```

### ip addr (h2)

```
lo: 127.0.0.1/8
eth0: 172.31.0.10/24 MAC 8a:ce:67:1b:82:56
```

### ip addr (roteador)

```
lo: 127.0.0.1/8
eth0: 172.31.0.254/24 MAC f6:8e:bf:a5:13:1e
eth1: 172.30.0.254/24 MAC 4e:dd:29:e9:5e:02
```

### ping h1->h2 (20 pkt)

```
20 packets transmitted, 20 received, 0% loss
rtt min/avg/max/mdev = 0.067/0.168/0.190/0.027 ms
```

### iperf3 TCP single

```
Transfer: 36.1 GBytes — 31.0 Gbits/sec — retries: 0
```

### iperf3 TCP -P4

```
Aggregate: 103 GBytes — 88.1 Gbits/sec — retransmissions: 1959
```

### iperf3 UDP 10M

```
Transfer: 11.9 MBytes — Jitter: 0.011 ms — Loss: 0/8632 (0%)
```

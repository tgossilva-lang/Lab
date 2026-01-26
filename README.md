# Lab

Repositório de estudos e testes.

## Script para desligar máquinas na rede

O script `shutdown_machines.sh` lê um arquivo `.txt` com nomes/endereços de máquinas (um por linha) e envia o comando de desligamento via SSH.

```bash
./shutdown_machines.sh examples/hosts.txt
```

Opções úteis:

```bash
SSH_USER=admin SSH_OPTIONS="-i ~/.ssh/id_rsa" ./shutdown_machines.sh hosts.txt
DRY_RUN=1 ./shutdown_machines.sh hosts.txt
```

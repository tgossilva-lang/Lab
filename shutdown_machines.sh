#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob

usage() {
  cat <<'USAGE'
Uso: shutdown_machines.sh <arquivo_hosts>

Lê um arquivo .txt com nomes/endereços de máquinas (um por linha) e envia
um comando de desligamento via SSH.

Variáveis de ambiente opcionais:
  SSH_USER      Usuário para conexão SSH (padrão: usuário atual)
  SSH_OPTIONS   Opções extras do SSH (ex.: "-i ~/.ssh/id_rsa -p 2222")
  SHUTDOWN_CMD  Comando remoto de desligamento (padrão: "sudo shutdown -h now")
  DRY_RUN       Se definido como "1", apenas exibe os comandos

Exemplo:
  SSH_USER=admin SSH_OPTIONS="-i ~/.ssh/id_rsa" ./shutdown_machines.sh hosts.txt
  DRY_RUN=1 ./shutdown_machines.sh hosts.txt
USAGE
}

if [[ ${1-} == "-h" || ${1-} == "--help" || $# -ne 1 ]]; then
  usage
  exit 0
fi

hosts_file="$1"

if [[ ! -f "$hosts_file" ]]; then
  echo "Arquivo não encontrado: $hosts_file" >&2
  exit 1
fi

ssh_user="${SSH_USER:-$(whoami)}"
ssh_options="${SSH_OPTIONS:-}"
shutdown_cmd="${SHUTDOWN_CMD:-sudo shutdown -h now}"

echo "Usando usuário SSH: $ssh_user"
[[ -n "$ssh_options" ]] && echo "Opções SSH: $ssh_options"

echo "Iniciando desligamento das máquinas em: $hosts_file"

echo "----------------------------------------------"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="${raw_line##*( )}"
  line="${line%%*( )}"

  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue

  host="$line"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY_RUN] ssh $ssh_options ${ssh_user}@${host} \"$shutdown_cmd\""
  else
    echo "Desligando: $host"
    ssh $ssh_options "${ssh_user}@${host}" "$shutdown_cmd"
  fi

done < "$hosts_file"

echo "----------------------------------------------"
echo "Processo concluído."

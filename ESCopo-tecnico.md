# Escopo Técnico, Arquitetura e Roadmap — Sistema de Gerenciamento Remoto de Laboratórios Windows

## 1) Visão geral do sistema e objetivos
O sistema proposto é uma plataforma centralizada para gerenciamento remoto de laboratórios Windows em ambiente corporativo/educacional, com foco em **operar em escala (≈500 máquinas)**, **reduzir dependência de scripts ad‑hoc**, **padronizar ações** e **aumentar a auditabilidade e a segurança**. O objetivo principal é viabilizar a execução de operações recorrentes (inventário, distribuição/coleto de arquivos, instalação silenciosa, comandos remotos e controle de energia) de forma **guiada por UI**, com **controle de concorrência** e **observabilidade**.

**Princípios-chave:**
- **Operação sem presença física** nos laboratórios.
- **Ações parametrizáveis e reutilizáveis** (templates), evitando scripts longos.
- **Segurança e auditoria** em todas as operações.
- **Arquitetura modular/extensível** para evoluções futuras.
- **Escalonamento progressivo**: primeiro na estação local; depois servidor dedicado.

## 2) Personas e casos de uso
**Admin (Você)**
- Cadastrar/descobrir máquinas e grupos.
- Disparar operações em massa com parâmetros e limites.
- Definir catálogos (software, templates de comandos, rotinas de fileops).
- Auditar ações por usuário e por máquina.

**Analista de TI**
- Executar ações delegadas (ex.: instalar pacote aprovado, copiar arquivos, reiniciar PCs).
- Consultar logs por laboratório.

**Professor (opcional/limitado)**
- Acionar ações predefinidas em sala (ex.: limpar pastas de alunos, distribuir arquivos de aula).
- Visualizar status do laboratório.

## 3) Requisitos funcionais e não funcionais
### 3.1 Requisitos funcionais (detalhados)
**Inventário e organização**
- Importar e sincronizar hosts do AD (OU(s) específicas).
- Cadastro manual/edição de máquinas quando necessário.
- Agrupar por laboratório, prédio, VLAN/sub-rede e tags (ex.: “prova”, “SafeLab”).
- Exibir status online/offline, último contato, hostname, IP, SO, usuário logado (quando possível).
- Filtros avançados e seleção: um lab, múltiplos labs, lista arbitrária, “1 máquina por lab”.

**Distribuição e coleta de arquivos/pastas**
- Envio de arquivo ou pasta para um ou múltiplos caminhos.
- Suporte a caminhos especiais: Public Desktop, Default Profile, Public Documents.
- Estratégias de cópia: sobrescrever, somente se diferente, validação por hash.
- Limpeza de arquivos/pastas antigos com regras de exclusão.
- Criação de atalhos (.lnk) em locais públicos ou perfil padrão.
- Coleta de arquivos/pastas de uma ou várias máquinas, com armazenamento central por máquina/data.
- Controle de concorrência por lab/VLAN, throttling e janelas de execução.
- Distribuição incremental/delta quando possível.

**Execução remota de ações e comandos**
- Biblioteca de comandos PowerShell parametrizados.
- Retorno de saída e logs por máquina.
- Ações “1 clique” para rotinas comuns (limpar pasta, criar diretório, editar registro, etc.).

**Instalação de software (silent)**
- Catálogo de pacotes com nome, versão, parâmetros silenciosos, pré-requisitos.
- Distribuição do instalador + execução remota.
- Validação pós‑instalação (serviço, arquivo, versão ou registro).
- Agendamento e execução em lote.

**Energia e controle remoto**
- Desligar/reiniciar máquinas em massa.
- Wake-on-LAN quando suportado (com limitações por VLAN/802.1x).
- Alternativas para WOL: tarefas agendadas locais, GPO existente, horários de boot.

**Substituição parcial de LanSchool (quando viável)**
- Bloqueio de sites/internet por máquina/grupo (via firewall/proxy ou políticas existentes).
- Bloqueio de aplicativos por hash/caminho (AppLocker/WDAC, se já existente).
- Se GPO nova for impossível, utilizar GPOs existentes editáveis ou agente local.

**Usuários, papéis e auditoria**
- Autenticação integrada ao AD (SSO ou LDAP/LDAPS).
- RBAC por grupos AD (Admin, Analista, Operador).
- Auditoria completa: quem fez o quê, quando, em quais máquinas.
- Histórico de jobs com status, logs e retry.

### 3.2 Requisitos não funcionais
- **Segurança:** criptografia em trânsito, validação de integridade, segregação de permissões.
- **Confiabilidade:** tolerância a falhas, retries configuráveis e registro de falhas.
- **Escalabilidade:** fila de jobs, throttling por lab/VLAN.
- **Observabilidade:** logs centralizados, métricas e alertas básicos.
- **Usabilidade:** UI moderna, responsiva e com feedback em tempo real.
- **Portabilidade:** rodar na estação local e migrar para servidor dedicado depois.

## 4) Arquitetura proposta (componentes) — agent‑based vs agentless
### 4.1 Opção A — Agent-based (serviço/agente nas máquinas)
**Como funciona:** Um agente Windows instalado nos hosts executa ações recebidas do servidor central e reporta status.

**Prós:**
- Opera bem através de VLANs e redes segmentadas.
- Permite execução offline/assíncrona (jobs pendentes).
- Suporta ações avançadas (bloqueios, monitoramento, inventário detalhado).
- Menor dependência de WinRM/SMB expostos.

**Contras:**
- Necessidade de instalar/manter agente em 500 máquinas.
- Requer estratégia de atualização do agente.
- Pode exigir exceções de antivírus ou firewall.

### 4.2 Opção B — Agentless (WinRM/SMB/WMI/PSRemoting)
**Como funciona:** O servidor dispara ações via WinRM/SMB/WMI sem instalar agente.

**Prós:**
- Não exige software adicional nos hosts.
- Implementação inicial mais rápida.

**Contras:**
- Depende de WinRM/SMB/WMI habilitados e acessíveis em todas as VLANs.
- Mais sensível a bloqueios de firewall e problemas de confiança.
- Escala pior em execuções massivas (conexões simultâneas limitadas).

**Recomendação prática:**
- **MVP**: iniciar com modelo agentless (aproveitando PSRemoting/SMB) para acelerar entregas.
- **Evolução**: migrar para agente leve para escala e funcionalidades avançadas.

## 4.3) Arquitetura Final (Decisão) — aplicada ao cenário real
### 4.3.1 Comparação agent-based vs agentless (com recomendação final)
**Agentless (WinRM/SMB/WMI/PSRemoting) — recomendado para o MVP**
- **Por quê:** permite começar rápido na sua estação Windows, sem depender de aprovação para instalar agentes ou criar GPOs novas.
- **VLAN/802.1x:** funciona quando as VLANs permitem WinRM/SMB/WMI; caso haja bloqueios, o alcance pode ser parcial.
- **Trade‑off:** menor robustez para operações offline e maior sensibilidade a firewall/portas.

**Agent-based (serviço leve nas máquinas) — recomendado como evolução**
- **Por quê:** melhora a escala e a confiabilidade, inclusive entre VLANs e máquinas offline.
- **Sem GPO nova:** instalação pode ser feita via execução remota/PKG existente, tarefas agendadas ou GPO já editável.
- **Trade‑off:** exige ciclo de implantação e atualização do agente.

**Decisão final:** **MVP agentless** para entrega rápida + **evolução para agent‑based** para escala, redes segmentadas e execução offline.

### 4.3.2 Arquitetura em componentes (prática)
1. **Web UI**: seleção de labs/PCs, parâmetros de ações e visualização de status em tempo real.
2. **API/Backend**: orquestração, autenticação AD, RBAC e criação de jobs.
3. **Job Queue/Workers**: fila, throttling, retries e execução controlada por lab/VLAN.
4. **Host Connector (MVP)**: WinRM/SMB/WMI para ações agentless.
5. **Agent (Evolução)**: serviço Windows com canal HTTPS/gRPC para ações assíncronas.
6. **Storage/Repo de arquivos**: repositório central de pacotes e arquivos (SMB).
7. **DB**: inventário, grupos, templates, jobs, logs e auditoria.

### 4.3.3 Fluxos principais (do clique à execução)
**Fluxo A — FileOps (enviar/atualizar/remover)**  
1) Usuário seleciona labs/hosts e define caminho (C:\\Temp, Public Desktop, Default Profile).  
2) API cria job com parâmetros e política de concorrência.  
3) Worker dispara ações via WinRM/SMB (MVP) ou agente (futuro).  
4) Host executa, retorna status/erros/hashes.  
5) UI exibe progresso por máquina e relatório final.

**Fluxo B — Coleta de arquivos/pastas**  
1) Seleção de alvos e caminho de origem.  
2) Worker copia para repositório central (\\servidor\\coletas\\HOST\\DATA).  
3) UI exibe sucesso/falha por host.

**Fluxo C — Instalação silenciosa**  
1) Seleção de pacote + parâmetros.  
2) Distribuição do instalador + execução silenciosa.  
3) Validação pós‑instalação (arquivo/serviço/versão).  
4) Log por máquina.

**Fluxo D — Desligar/Reiniciar/Ligar**  
1) Seleção de alvos.  
2) Execução via comando remoto (shutdown/restart).  
3) WOL se disponível; caso contrário, agendamento local (quando possível).

### 4.3.4 Estratégia de segurança
- **Autenticação:** AD (Kerberos/NTLM ou LDAP/LDAPS) na API.
- **RBAC:** grupos AD mapeados para perfis (Admin/Analista/Operador).
- **Autenticação do agente (futuro):** certificados por máquina + mutual TLS.
- **Auditoria:** logs de jobs (quem, quando, alvo, parâmetros, sucesso/falha).

### 4.3.5 Estratégia de escala/rede
- **Concorrência por lab/VLAN:** limite global e por segmento.
- **Throttling:** janela de execução e controle de throughput.
- **Retries inteligentes:** backoff exponencial e re‑fila para máquinas offline.
- **Delta/hashes:** envio apenas quando conteúdo difere.

### 4.3.6 Implantação do MVP e migração
**MVP na estação Windows (fase 1)**  
- Backend + UI local (localhost), DB local (PostgreSQL/SQL Express).  
- Repositório de arquivos em share SMB acessível.  
- Workers executando localmente com credenciais delegadas.

**Migração para servidor dedicado (fase 2)**  
- Mover API/Workers/DB para servidor Windows.  
- Reapontar repositório de arquivos e atualizar DNS/URL.  
- Evoluir para agente quando necessário.

### 4.3.7 ADR resumido (Architecture Decision Record)
**Contexto:** 500 máquinas, VLANs múltiplas, sem GPO nova, MVP local.  
**Decisão:** iniciar com agentless (WinRM/SMB/WMI) e evoluir para agente leve.  
**Consequências positivas:** entrega rápida, menos dependência de mudanças de infra.  
**Consequências negativas:** limitações por firewall/VLAN e menor suporte offline até o agente existir.  
**Alternativas consideradas:** agente desde o início (mais robusto, porém mais difícil de implantar).

## 5) Modelo de segurança (AD, RBAC, auditoria)
- **Autenticação:** integração AD (Kerberos/LDAP/LDAPS). 
- **RBAC:** mapear grupos AD para papéis internos (Admin/Analista/Operador).
- **Autorização por ação:** cada ação possui “policy” mínima.
- **Auditoria:** logs imutáveis (job id, user, alvo, parâmetros, horário, status).
- **Segredos:** vault local (DPAPI) na fase 1, migrável para secrets manager na fase 2.
- **Assinatura de payloads:** validação de comandos e pacotes antes da execução.

## 6) Estratégia de distribuição/coleta sem saturar a rede
- **Fila de jobs com throttling:** limite global e por lab/VLAN.
- **Batching:** distribuir em lotes (ex.: 20 máquinas por vez).
- **Delta/incremental:** usar hash para envio somente se diferente.
- **Janela de execução:** horários de baixa utilização.
- **Cache local (futuro):** replicar para um “cache node” por prédio.

## 7) Módulos do sistema
1. **Inventário** — AD sync, cadastro manual, tags e status.
2. **Jobs/Orquestração** — fila, retries, concorrência e agendamento.
3. **FileOps** — distribuição/remoção/coleta de arquivos.
4. **CommandOps** — execução remota de comandos e templates.
5. **Software Deploy** — catálogo, instalação silenciosa e validação.
6. **Power Control** — desligar/reiniciar/WOL.
7. **Policies/Bloqueios** — bloqueio de sites/apps (limitado por GPO existente).
8. **Observabilidade** — logs, métricas, dashboards.
9. **Admin/RBAC** — usuários, permissões e auditoria.

## 7.1) Escopo Técnico Executável — FileOps (MVP Agentless)
> **Contexto do MVP:** execução **agentless** via WinRM/PowerShell Remoting + SMB, rodando na estação Windows, com controle de concorrência para ~500 máquinas.

### 1) O que entra no FileOps MVP (escopo fechado)
- **Envio/atualização** de arquivos/pastas para destinos definidos (incluindo destinos especiais).
- **Remoção** de arquivos/pastas antigos (com lista de exclusões).
- **Criação de atalhos (.lnk)** em locais públicos (Public Desktop, Default Profile, Public Documents).
- **Coleta** de arquivos/pastas de uma ou várias máquinas para repositório central.
- **Fila de jobs**, retries, logs por host e auditoria.
- **Controle de concorrência e throttling** para evitar saturar a rede.

> **Fora do escopo do MVP:** cache distribuído por prédio, compressão inteligente por conteúdo, deduplicação global, agente local, controle avançado de banda por interface, integração com GPO nova.

### 2) Modelo de dados mínimo (entidades)
- **Host**: id, hostname, ip, lab_id, vlan_id, tags[], status, last_seen.
- **Lab/Tag**: id, name, type (lab/tag), metadata.
- **Job**: id, type=FileOps, created_by, created_at, status, target_selector, concurrency_policy.
- **JobRun**: id, job_id, host_id, status, started_at, finished_at, retry_count, exit_code, summary.
- **FilePackage (Artifact)**: id, name, source_path, hash, size, version, created_by, created_at.
- **FileOpAction**: id, job_id, action_type, params_json, validation_rules.
- **AuditLog**: id, actor, action, target, timestamp, payload_hash, outcome.

### 3) Tipos de ações FileOps (parâmetros e validações)
**CopyFile**  
- params: source_path, dest_path, overwrite(bool), only_if_different(bool).  
- validações: destino existe? permissões de escrita? caminho permitido?

**CopyFolder**  
- params: source_path, dest_path, overwrite(bool), exclude_patterns[].  
- validações: tamanho máximo (opcional), destino permitido, source acessível.

**SyncFolder (somente se diferente)**  
- params: source_path, dest_path, strategy(hash|mtime|size), exclude_patterns[].  
- validações: strategy obrigatória; destino permitido.

**DeletePath**  
- params: target_path, recursive(bool), exclude_patterns[].  
- validações: bloquear caminhos críticos (C:\\Windows, C:\\Program Files).

**CreateShortcut**  
- params: target_path, shortcut_path, icon_path?, args?.  
- validações: target existe; destino permitido (Public Desktop/Default/Public Documents).

**CollectPath**  
- params: source_path, collect_root (ex: \\\\servidor\\coletas), include_patterns[].  
- validações: caminho de coleta acessível; quota mínima.

**Destinos especiais (mapeamento):**  
- Public Desktop → `C:\\Users\\Public\\Desktop`  
- Default Profile → `C:\\Users\\Default\\Desktop` (ou subpasta indicada)  
- Public Documents → `C:\\Users\\Public\\Documents`

### 4) Estratégia de transferência (AGENTLESS)
**Cópia via SMB/robocopy (recomendado):**  
- Usar `robocopy` quando copiar pastas grandes (robusto e com retries).  
- Flags sugeridas: `/MIR` (sync), `/XO` (excluir arquivos mais antigos), `/FFT` (tolerância), `/R:2 /W:5` (retries), `/Z` (restartable), `/NP` (no progress), `/LOG+` (log).  

**Execução via PSRemoting (quando precisa rodar no host):**  
- Enviar comando para execução local no host (ex.: criação de atalhos .lnk).  
- Usar `Invoke-Command` com credenciais administrativas.  

**Permissões/UAC/credenciais:**  
- Usar conta administrativa de domínio (delegada).  
- Validar acesso SMB ao share e ao destino local.  
- No MVP, armazenar credenciais de forma segura (DPAPI no Windows).  

### 5) Escala e rede
**Concorrência:**  
- Limite global (ex.: 30 hosts simultâneos) + limite por lab/VLAN (ex.: 5–10).  

**Throttling:**  
- Ajustar `/IPG` do robocopy para limitar throughput.  
- Escalonar lotes por janela de execução (opcional).  

**Retry/Timeout:**  
- Timeout por host (ex.: 15–30 min).  
- Backoff exponencial e máximo de 2–3 tentativas.  

### 6) Integridade
- **Somente se diferente:** usar hash (SHA256) ou `mtime+size` conforme volume.  
- **Logs por arquivo/pasta:** saída de robocopy ou relatório de diff.  
- **Resumo por host:** bytes transferidos, arquivos alterados, erros.

### 7) Fluxo end-to-end
**UI → API → Fila → Execução → Retorno → Auditoria**  
Estados do job: **Queued, Running, Partial, Failed, Completed, Canceled**.

### 8) Checklist de pré-requisitos (MVP agentless)
- **WinRM habilitado:** `winrm quickconfig` e verificação de listeners.  
- **Portas/SMB:** 5985/5986 (WinRM), 445 (SMB).  
- **Credenciais:** conta admin delegada + armazenamento seguro (DPAPI).  
- **Acesso ao share:** \\servidor\\repo acessível por todas as máquinas alvo.

### 9) Riscos e mitigação (FileOps)
- **VLANs bloqueiam SMB/WinRM:** mitigar com janelas, exceções de firewall, ou migrar para agente.  
- **Hosts offline:** fila com retry e janela de execução.  
- **Saturação de rede:** throttling e limites por lab/VLAN.  
- **Permissões insuficientes:** validar com teste prévio por host.

### Exemplo de payload JSON (job FileOps)
```json
{
  "type": "FileOps",
  "targets": {
    "labs": ["LabA", "LabB"],
    "mode": "one_per_lab"
  },
  "concurrency": {
    "global": 20,
    "per_lab": 5,
    "throttle_ipg_ms": 50
  },
  "actions": [
    {
      "action": "SyncFolder",
      "source_path": "\\\\servidor\\repo\\SafeLab",
      "dest_path": "C:\\SafeLab_Aluno",
      "strategy": "hash"
    },
    {
      "action": "DeletePath",
      "target_path": "C:\\SafeLab_Aluno_Old",
      "recursive": true,
      "exclude_patterns": ["keep.txt"]
    },
    {
      "action": "CreateShortcut",
      "target_path": "C:\\SafeLab_Aluno\\SafeLab.exe",
      "shortcut_path": "C:\\Users\\Public\\Desktop\\SafeLab.lnk",
      "icon_path": "C:\\SafeLab_Aluno\\SafeLab.ico"
    }
  ],
  "audit": {
    "requested_by": "user@dominio.local",
    "job_note": "Atualização SafeLab + limpeza"
  }
}
```

## 8) Banco de dados e armazenamento
**Banco relacional (ex.: PostgreSQL):**
- Hosts, grupos, tags, labs, VLANs.
- Usuários e roles (mapeados a grupos AD).
- Catálogo de pacotes, templates de comandos.
- Jobs e execuções (status, logs resumidos).

**Armazenamento de arquivos (ex.: SMB/objeto):**
- Repositório de pacotes e arquivos.
- Coletas organizadas por host/data.

**Logs detalhados:**
- Centralizados (ex.: Elasticsearch/Loki) conforme evolução.

## 9) Roadmap
### MVP (0–3 meses)
- Inventário + seleção por lab/tag.
- FileOps básico: copiar/remover pasta, criar atalhos.
- Execução de comandos predefinidos.
- Instalação silenciosa básica (MSI/EXE).
- Desligar/reiniciar.
- UI com feedback em tempo real.

### Evolução 1 (3–6 meses)
- Throttling avançado por VLAN.
- Catálogo de software com validação pós‑instalação.
- Coleta em massa com storage central.
- Melhorias de auditoria e métricas.

### Evolução 2 (6–12 meses)
- Agente leve para ações offline.
- WOL aprimorado com proxy/relay por VLAN.
- Bloqueios tipo LanSchool (dependente de GPO/agent).
- Plugins para novos módulos.

## 10) Stack tecnológica sugerida
**Backend:**
- .NET (ASP.NET Core) ou Node.js (NestJS), por compatibilidade Windows.
- Workers para fila (Hangfire/Quartz ou BullMQ/RabbitMQ).

**Comunicação com hosts:**
- MVP: PowerShell Remoting/WinRM + SMB.
- Evolução: Agente Windows (service) com gRPC/HTTPS.

**Frontend:**
- React ou Angular com UI moderna.

**Banco:**
- PostgreSQL ou SQL Server Express (fase 1 local).

**Autenticação:**
- AD/LDAP/SSO (Kerberos/NTLM via Windows Auth).

## 11) Riscos e dependências
- **Limitação de GPO:** bloqueios avançados podem não ser viáveis sem GPO nova.
- **WinRM/SMB bloqueados:** inviabiliza agentless em algumas VLANs.
- **WOL limitado:** 802.1x e VLANs podem bloquear.
- **Escala de rede:** risco de saturação sem throttling.

## 12) Exemplos de fluxos e telas principais
**Fluxo 1 — Distribuir pasta para 5 labs**
1. Admin seleciona labs → define caminho destino.
2. Sistema cria job → fila com throttling por lab.
3. Workers executam cópia incremental → status em tempo real.
4. Logs por máquina e resumo final.

**Fluxo 2 — Instalar software em lote**
1. Seleciona pacote do catálogo.
2. Define parâmetros silenciosos e alvo.
3. Job dispara instalação → validação pós‑install.
4. Relatório de sucesso/falha.

**Telas principais**
- Dashboard de labs/hosts.
- Tela de seleção em massa.
- Tela de jobs com progresso.
- Catálogo de pacotes e comandos.
- Logs/auditoria.

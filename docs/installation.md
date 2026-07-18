# Guia de instalação

Este documento descreve como instalar o Zabbix Server e os agentes utilizados neste projeto.

## Arquitetura do projeto

O ambiente será composto por:

* Uma VPS com Ubuntu Server 24.04 executando o Zabbix Server;
* Servidores Linux monitorados com Zabbix Agent 2;
* Servidores Windows Server monitorados com Zabbix Agent 2;
* Comunicação entre os agentes e o Zabbix Server;
* Interface web para visualização de métricas e alertas.

## Requisitos do Zabbix Server

Requisitos mínimos recomendados para testes:

* Ubuntu Server 24.04 LTS;
* 2 vCPUs;
* 4 GB de memória RAM;
* 40 GB de armazenamento;
* Acesso administrativo com `sudo`;
* IP fixo ou endereço DNS;
* Portas necessárias liberadas no firewall.

## Portas utilizadas

| Porta | Protocolo | Função              |
| ----- | --------- | ------------------- |
| 22    | TCP       | Acesso SSH          |
| 80    | TCP       | Interface web HTTP  |
| 443   | TCP       | Interface web HTTPS |
| 10050 | TCP       | Zabbix Agent        |
| 10051 | TCP       | Zabbix Server       |

Não deixe as portas `10050` e `10051` abertas para toda a internet sem necessidade.

Sempre que possível, limite o acesso ao IP dos servidores autorizados.

## Instalação do Zabbix Server

Clone o repositório na VPS:

```bash
git clone https://github.com/Gabrielpalhanogomes2803/zabbix-infrastructure.git
```

Entre na pasta:

```bash
cd zabbix-infrastructure
```

Atualize as permissões:

```bash
chmod +x scripts/server/install-zabbix-server.sh
```

Execute o instalador:

```bash
sudo ./scripts/server/install-zabbix-server.sh
```

Durante a instalação, será solicitada uma senha para o banco de dados do Zabbix.

Utilize uma senha forte e não publique essa senha no GitHub.

## Acesso ao painel

Após a instalação, acesse:

```text
http://IP_DO_ZABBIX_SERVER
```

Credenciais iniciais:

```text
Usuário: Admin
Senha: zabbix
```

Troque a senha padrão imediatamente após o primeiro acesso.

## Instalação do agente Linux

No servidor Linux que será monitorado, clone o projeto:

```bash
git clone https://github.com/Gabrielpalhanogomes2803/zabbix-infrastructure.git
```

Entre na pasta:

```bash
cd zabbix-infrastructure
```

Dê permissão ao script:

```bash
chmod +x scripts/agents/linux/install-zabbix-agent.sh
```

Execute:

```bash
sudo ./scripts/agents/linux/install-zabbix-agent.sh
```

O script solicitará:

* IP ou DNS do Zabbix Server;
* Nome do host que será cadastrado no painel.

O nome informado no agente deve ser exatamente igual ao nome cadastrado no Zabbix Server.

Também é possível passar as informações diretamente:

```bash
sudo ZABBIX_SERVER_IP="IP_DO_ZABBIX" \
HOST_NAME="servidor-linux-01" \
./scripts/agents/linux/install-zabbix-agent.sh
```

## Verificação do agente Linux

Verifique o serviço:

```bash
sudo systemctl status zabbix-agent2
```

Confira os logs:

```bash
sudo journalctl -u zabbix-agent2 -f
```

Confira se a porta está aberta:

```bash
sudo ss -lntp | grep 10050
```

## Instalação do agente Windows Server

No Windows Server, abra o PowerShell como administrador.

Caso o repositório já esteja disponível no servidor, entre na pasta:

```powershell
cd C:\zabbix-infrastructure
```

Execute o script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

.\scripts\agents\windows\install-zabbix-agent.ps1 `
    -ZabbixServer "IP_DO_ZABBIX" `
    -HostName "SERVIDOR-WINDOWS-01"
```

O nome informado em `HostName` deve ser exatamente igual ao nome cadastrado no painel do Zabbix.

## Verificação do agente Windows

Verifique o serviço:

```powershell
Get-Service "Zabbix Agent 2"
```

Verifique se a porta está escutando:

```powershell
Get-NetTCPConnection -LocalPort 10050 -ErrorAction SilentlyContinue
```

Verifique a regra do firewall:

```powershell
Get-NetFirewallRule -DisplayName "Zabbix Agent 2 TCP 10050"
```

## Cadastro do host no Zabbix

No painel web:

1. Acesse **Data collection**;
2. Entre em **Hosts**;
3. Clique em **Create host**;
4. Informe o mesmo nome configurado no agente;
5. Adicione o host a um grupo;
6. Configure a interface Agent;
7. Informe o IP do servidor monitorado;
8. Associe um template;
9. Salve o host.

Para Linux, utilize inicialmente um template do Linux por Zabbix Agent.

Para Windows Server, utilize inicialmente um template do Windows por Zabbix Agent.

## Primeiras métricas

Após cadastrar o host, confirme se o Zabbix está recebendo:

* Uso de CPU;
* Memória RAM;
* Espaço em disco;
* Tráfego de rede;
* Uptime;
* Processos;
* Disponibilidade do agente.

## Atualização do projeto

No computador local:

```bash
git add .
git commit -m "Descrição da alteração"
git push
```

Na VPS ou nos servidores:

```bash
cd zabbix-infrastructure
git pull
```

## Segurança

Nunca envie para o GitHub:

* Senhas;
* Tokens;
* Arquivos `.env`;
* Chaves privadas;
* Certificados privados;
* Arquivos PSK;
* Credenciais do banco de dados;
* Informações sensíveis dos servidores.

Antes de colocar o ambiente em produção, configure:

* HTTPS no painel;
* TLS ou PSK entre agentes e servidor;
* Restrições de firewall;
* Backup do banco;
* Senhas fortes;
* Controle de acesso por usuário.

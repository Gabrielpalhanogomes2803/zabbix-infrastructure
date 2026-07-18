#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZabbixServer,

    [Parameter(Mandatory = $false)]
    [string]$HostName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [string]$ZabbixVersion = "7.0.19"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host $Message
    Write-Host "=========================================================="
}

$Architecture = $env:PROCESSOR_ARCHITECTURE

if ($Architecture -ne "AMD64") {
    throw "Este script foi preparado para Windows Server 64 bits."
}

$DownloadDirectory = "C:\Temp\Zabbix"
$MsiFile = Join-Path `
    $DownloadDirectory `
    "zabbix_agent2-$ZabbixVersion-windows-amd64-openssl.msi"

$DownloadUrl = `
    "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$ZabbixVersion/zabbix_agent2-$ZabbixVersion-windows-amd64-openssl.msi"

$LogFile = Join-Path $DownloadDirectory "zabbix-agent2-install.log"

Write-Step "1. Criando diretório temporário"

New-Item `
    -ItemType Directory `
    -Path $DownloadDirectory `
    -Force | Out-Null

Write-Step "2. Baixando o Zabbix Agent 2"

Invoke-WebRequest `
    -Uri $DownloadUrl `
    -OutFile $MsiFile `
    -UseBasicParsing

if (-not (Test-Path $MsiFile)) {
    throw "O instalador não foi baixado."
}

Write-Step "3. Instalando o Zabbix Agent 2"

$Arguments = @(
    "/i"
    "`"$MsiFile`""
    "/qn"
    "/norestart"
    "/l*v"
    "`"$LogFile`""
    "SERVER=$ZabbixServer"
    "SERVERACTIVE=$ZabbixServer"
    "HOSTNAME=$HostName"
)

$Process = Start-Process `
    -FilePath "msiexec.exe" `
    -ArgumentList $Arguments `
    -Wait `
    -PassThru

if ($Process.ExitCode -notin @(0, 3010)) {
    throw "A instalação falhou. Código: $($Process.ExitCode). Consulte $LogFile"
}

Write-Step "4. Criando regra no Firewall do Windows"

$ExistingRule = Get-NetFirewallRule `
    -DisplayName "Zabbix Agent 2 TCP 10050" `
    -ErrorAction SilentlyContinue

if (-not $ExistingRule) {
    New-NetFirewallRule `
        -DisplayName "Zabbix Agent 2 TCP 10050" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 10050 `
        -RemoteAddress $ZabbixServer `
        -Action Allow | Out-Null
}

Write-Step "5. Iniciando o serviço"

$Service = Get-Service `
    -Name "Zabbix Agent 2" `
    -ErrorAction SilentlyContinue

if (-not $Service) {
    throw "O serviço Zabbix Agent 2 não foi encontrado."
}

Set-Service `
    -Name "Zabbix Agent 2" `
    -StartupType Automatic

Restart-Service `
    -Name "Zabbix Agent 2" `
    -Force

Write-Step "6. Verificando o resultado"

$Service = Get-Service -Name "Zabbix Agent 2"

Write-Host "Serviço: $($Service.Name)"
Write-Host "Status: $($Service.Status)"
Write-Host "Inicialização: automática"
Write-Host "Hostname cadastrado: $HostName"
Write-Host "Zabbix Server: $ZabbixServer"

if ($Service.Status -ne "Running") {
    throw "O serviço foi instalado, mas não está em execução."
}

Write-Host ""
Write-Host "[OK] Zabbix Agent 2 instalado com sucesso."
Write-Host "Cadastre no painel exatamente o hostname: $HostName"
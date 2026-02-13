# Versao 1.3 - Comparacao e Restauracao de Arquivos Divergentes
# Data: 06/02/2026
# Criado por: Diego Rocha (stag)


# ======================================
# 1. VALIDACAO INICIAL
# ======================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$basePath = "$scriptPath" 
$csvLista = Join-Path $basePath "lista_modelo_ip.csv"

if (!(Test-Path $csvLista)) {
    Write-Host "ERRO: Arquivo lista_modelo_ip.csv nao encontrado." -ForegroundColor Red
    Read-Host "Pressione ENTER para sair..."
    exit 1
}

# ======================================
# 2. IDENTIFICAR MODELO POR IP
# ======================================
$dadosIp = Import-Csv -Path $csvLista -Encoding UTF8
$dictPorIP = @{}
foreach ($linha in $dadosIp) { $dictPorIP[$linha.IP.Trim()] = $linha.MODELO.Trim().ToUpper() }

$ipPC = Read-Host "Digite o IP do PC para VALIDAR e RESTAURAR"

if (!$dictPorIP.ContainsKey($ipPC)) {
    Write-Host "ERRO: IP nao cadastrado." -ForegroundColor Red
    exit 1
}

$modeloPC = $dictPorIP[$ipPC]
$fileBaseline = Join-Path $basePath "hashtable_baseline_${modeloPC}.csv"
$fileRemoto = Join-Path $basePath "hashtable_remoto_${ipPC}_${modeloPC}.csv"

if (!(Test-Path $fileBaseline)) {
    Write-Host "ERRO: Baseline nao encontrada: $fileBaseline" -ForegroundColor Red
    exit 1
}
if (!(Test-Path $fileRemoto)) {
    Write-Host "ERRO: Hash remoto nao encontrado. Rode o script de SYNC primeiro." -ForegroundColor Red
    exit 1
}

# ======================================
# 3. CONECTAR AO PC (DRIVE Z) 
# ======================================
Write-Host "Tentando conectar ao PC $ipPC..." -ForegroundColor Cyan

$cred = Get-Credential -Message "Digite as credenciais para acessar o PC"

cmd /c "net use * /delete /y" 2>$null | Out-Null

$compartilhamentos = @("PC", "pc", "Pc")
$conectado = $false
$pathZ = ""

foreach ($share in $compartilhamentos) {
    try {
        $pathZ = "\\$ipPC\$share"
        Write-Host "  Tentando: $pathZ" -ForegroundColor Gray
        
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $pathZ -Credential $cred -ErrorAction Stop | Out-Null
        
        Write-Host "CONECTADO COM SUCESSO: Drive Z: mapeado para $pathZ" -ForegroundColor Green
        $conectado = $true
        break
        
    } catch {
        Write-Host "  Falhou: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor DarkYellow
    }
}

if (-not $conectado) {
    Write-Host "`nERRO NA CONEXAO: Nao foi possivel conectar ao PC." -ForegroundColor Red
    Write-Host "Possíveis causas:" -ForegroundColor Yellow
    Write-Host "  1. O compartilhamento 'PC' nao existe no PC" -ForegroundColor Gray
    Write-Host "  2. Credenciais incorretas" -ForegroundColor Gray
    Write-Host "  3. PC inacessivel ou firewall bloqueando" -ForegroundColor Gray
    Write-Host "  4. Nome do compartilhamento pode ser diferente" -ForegroundColor Gray
    Write-Host "`nDica: Tente verificar manualmente com:" -ForegroundColor Cyan
    Write-Host "  net view \\$ipPC" -ForegroundColor White
    Write-Host "`nPressione ENTER para sair..." -ForegroundColor Yellow
    Read-Host
    exit 1
}


# ======================================
# 4. CARREGAR DADOS E COMPARAR 
# ======================================

$hashesBaseline = Import-Csv $fileBaseline
$hashesRemoto = Import-Csv $fileRemoto

$tabelaRemota = @{}
foreach ($item in $hashesRemoto) {
    $relativoRemoto = $item.Path.Substring($item.Path.ToLower().IndexOf("\PC\"))
    $tabelaRemota[$relativoRemoto] = $item.Hash
}

Write-Host "Iniciando comparacao baseada na Baseline..." -ForegroundColor Yellow
$countRestaurados = 0
$countErros = 0

foreach ($base in $hashesBaseline) {
    $indexPC = $base.Path.ToLower().IndexOf("\PC\")
    if ($indexPC -lt 0) { continue } 
    $caminhoRelativo = $base.Path.Substring($indexPC) 
    $caminhoLocalNoPC = $base.Path
    

    $subPath = $caminhoRelativo.Substring(7) 
    $destinoZ = Join-Path "Z:\" $subPath

    $hashRemotoAtual = $tabelaRemota[$caminhoRelativo]

    if ($null -eq $hashRemotoAtual -or $hashRemotoAtual -ne $base.Hash) {
        
        $status = if ($null -eq $hashRemotoAtual) { "[AUSENTE]" } else { "[DIVERGENTE]" }
        Write-Host "   $status -> $subPath" -ForegroundColor Magenta
        
        try {
            $dirDestino = Split-Path $destinoZ -Parent
            if (!(Test-Path $dirDestino)) {
                New-Item -ItemType Directory -Path $dirDestino -Force | Out-Null
            }

            Remove-Item $destinoZ -Force -ErrorAction SilentlyContinue
            Copy-Item -Path $caminhoLocalNoPC -Destination $destinoZ -Force -ErrorAction Stop -Verbose
            
            Write-Host "      + Sucesso: Arquivo restaurado." -ForegroundColor Green
            $countRestaurados++
        } catch { 
            Write-Host "      ! Erro: $($_.Exception.Message)" -ForegroundColor Red
            $countErros++ 
        }
    }
}

# ======================================
# 5. FINALIZACAO
# ======================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "RELATORIO DE REPARO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Arquivos restaurados/corrigidos: $countRestaurados" -ForegroundColor Yellow
Write-Host "Falhas no processo: $countErros" -ForegroundColor Red

Remove-PSDrive -Name "Z" -Force -ErrorAction SilentlyContinue

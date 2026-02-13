# Versao 1.2 - Gerar HashTable de PC Remoto
# Data: 05/02/2026
# Criado por: Diego Rocha (stag)

# ======================================
# 1. VALIDACAO INICIAL
# ======================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$basePath = "$scriptPath" 
$csvPath = Join-Path $basePath "lista_modelo_ip.csv"

if (!(Test-Path $csvPath)) {
    Write-Host "ERRO: Arquivo CSV nao encontrado em: $csvPath" -ForegroundColor Red
    Write-Host "Pressione ENTER para sair..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

# ======================================
# 2. LER CSV E CRIAR DICIONARIO
# ======================================
try {
    $dados = Import-Csv -Path $csvPath -Encoding UTF8
} catch {
    Write-Host "ERRO ao ler CSV: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Pressione ENTER para sair..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

$dictPorIP = @{}
foreach ($linha in $dados) {
    if ($linha.IP -and $linha.MODELO) {
        $dictPorIP[$linha.IP.Trim()] = $linha.MODELO.Trim().ToUpper()
    }
}

# ======================================
# 3. OBTER IP E VALIDAR
# ======================================
$ipPC = Read-Host "Digite o IP do PC"

if (!$dictPorIP.ContainsKey($ipPC)) {
    Write-Host "ERRO: IP '$ipPC' nao encontrado na planilha." -ForegroundColor Red
    Write-Host "IPs disponiveis: $($dictPorIP.Keys -join ', ')" -ForegroundColor Yellow
    Write-Host "Pressione ENTER para sair..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

$modeloPC = $dictPorIP[$ipPC]
Write-Host "Modelo identificado: $modeloPC" -ForegroundColor Green

# ======================================
# 4. CONECTAR AO PC REMOTO
# ======================================
Write-Host "Tentando conectar ao PC $ipPC..." -ForegroundColor Cyan

$cred = Get-Credential -Message "Digite as credenciais para acessar o PC"

cmd /c "net use * /delete /y" 2>$null | Out-Null

$compartilhamentos = @("pc", "PC", "Pc")
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
    Write-Host "  1. O compartilhamento 'pc' nao existe no PC" -ForegroundColor Gray
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
# 5. DECLARAR FUNCAO
# ======================================
function Find-RemoteFolderCaseInsensitive {
    param(
        [string]$BasePath,
        [string]$RelativePath
    )
    
    $partes = $RelativePath -split '\\' | Where-Object { $_ -ne "" }
    $caminhoAtual = $BasePath
    
    foreach ($parte in $partes) {
        $pastas = Get-ChildItem -Path $caminhoAtual -Directory -ErrorAction SilentlyContinue
        $pastaEncontrada = $null
        
        foreach ($pasta in $pastas) {
            if ($pasta.Name.ToLower() -eq $parte.ToLower()) {
                $pastaEncontrada = $pasta
                break
            }
        }
        
        if ($pastaEncontrada) {
            $caminhoAtual = $pastaEncontrada.FullName
        } else {
            return $null
        }
    }
    
    return $caminhoAtual
}

# ======================================
# 6. CONFIGURAR PASTAS
# ======================================
$pastasConfig = @(
    @{RemotoRelativo = "Services"; LocalRelativo = "PC\Service"},
    @{RemotoRelativo = "PCAPI"; LocalRelativo = "PC\PCAPI"}
)

if ($modeloPC -eq "PCA") {
    Write-Host "Adicionando extras para PCA..." -ForegroundColor Cyan
    $pastasConfig += @{RemotoRelativo = "Databases"; LocalRelativo = "PCA\Databases"}
    $pastasConfig += @{RemotoRelativo = "Applications"; LocalRelativo = "PCA\Applications"}
}
elseif ($modeloPC -eq "PCB") {
    Write-Host "Adicionando extras para PCB..." -ForegroundColor Cyan
    $pastasConfig += @{RemotoRelativo = "Databases"; LocalRelativo = "PCB\Databases"}
    $pastasConfig += @{RemotoRelativo = "Applications"; LocalRelativo = "PCB\Applications"}
    $pastasConfig += @{RemotoRelativo = "Applications\Camera"; LocalRelativo = "PCB\Applications\Camera"}
}


# ======================================
# 7. DEFINIR CAMINHO DO ARQUIVO HASHTABLE
# ======================================
$remoteHashTable = Join-Path $basePath "hashtable_remoto_${ipPC}_${modeloPC}.csv"
Write-Host "Arquivo de hashtable sera salvo em: $remoteHashTable" -ForegroundColor Cyan

if (Test-Path $remoteHashTable) {
    $sobrescrever = Read-Host "Arquivo hashtable ja existe. Sobrescrever? [S]im [N]ao"
    if ($sobrescrever -ne "S") {
        Write-Host "Operacao cancelada pelo usuario." -ForegroundColor Yellow
        Remove-PSDrive -Name "Z" -Force -ErrorAction SilentlyContinue
        Write-Host "Pressione ENTER para sair..." -ForegroundColor Yellow
        Read-Host
        exit 0
    }
}

# ======================================
# 8. PROCESSAR PASTAS E GERAR HASHTABLE
# ======================================
$todosHashes = @()
$totalArquivos = 0

foreach ($item in $pastasConfig) {
    $origem = Find-RemoteFolderCaseInsensitive -BasePath "Z:\" -RelativePath $item.RemotoRelativo
    
    Write-Host "`n=== Processando: $($item.RemotoRelativo) ===" -ForegroundColor Yellow
    
    if (!$origem -or !(Test-Path $origem)) {
        Write-Host "  AVISO: Pasta remota nao encontrada: Z:\$($item.RemotoRelativo)" -ForegroundColor Red
        continue
    }
    
    Write-Host "  Origem remota: $origem" -ForegroundColor Gray
    
    $arquivos = Get-ChildItem -Path $origem -ErrorAction SilentlyContinue | Where-Object {!$_.PSIsContainer}
    
    if ($arquivos) {
        Write-Host "  Calculando hashes de $($arquivos.Count) arquivos..." -ForegroundColor Cyan
        
        foreach ($arquivo in $arquivos) {
            try {
                $hashObj = Get-FileHash -Path $arquivo.FullName -Algorithm SHA256 -ErrorAction Stop
                
                $caminhoEquivalente = Join-Path $basePath $modeloPC
                $caminhoEquivalente = Join-Path $caminhoEquivalente $item.LocalRelativo
                $caminhoEquivalente = Join-Path $caminhoEquivalente $arquivo.Name
                
                $todosHashes += [PSCustomObject]@{
                    Path = $caminhoEquivalente
                    Hash = $hashObj.Hash
                }
                
                $totalArquivos++
                Write-Host "    [$totalArquivos] $($arquivo.Name)" -ForegroundColor Gray
                
            } catch {
                Write-Host "    ! ERRO ao calcular hash de $($arquivo.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  Pasta vazia ou sem arquivos" -ForegroundColor Gray
    }
}

# ======================================
# 9. SALVAR HASHTABLE NO FORMATO CORRETO
# ======================================
if ($todosHashes.Count -gt 0) {
    try {
        $todosHashes | Export-Csv -Path $remoteHashTable -NoTypeInformation -Encoding UTF8
        
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "HASHTABLE GERADO COM SUCESSO!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Total de arquivos processados: $($todosHashes.Count)" -ForegroundColor Yellow
        Write-Host "Arquivo salvo em:" -ForegroundColor Cyan
        Write-Host "  $remoteHashTable" -ForegroundColor White
        
    } catch {
        Write-Host "`nERRO ao salvar hashtable: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nNenhum arquivo encontrado para gerar hashtable" -ForegroundColor Red
}

# ======================================
# 10. DESCONECTAR
# ======================================
Remove-PSDrive -Name "Z" -Force -ErrorAction SilentlyContinue

Write-Host "`nProcesso concluido!" -ForegroundColor Green

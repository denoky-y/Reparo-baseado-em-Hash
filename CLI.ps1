$opcoes = @("Baseline", "HashTable", "comparar HashTable", "Sair")

$mapaScripts = @{
    "Baseline"           = "make_base_hashtable"
    "HashTable"          = "make_remote_hashtable"
    "comparar HashTable" = "compa_hashtables"
}

$selecionado = 0
$rodando = $true

[Console]::CursorVisible = $false

while ($rodando) {
    Clear-Host
    Write-Host "
     _                _______          _ 
    | |              |__   __|        | |
 ___| |_ __ _  __ _     | | ___  ___ | |
/ __| __/ _ ` |/ _`  |    | |/ _ \ / _ \| |
\__ \ || (_| | (_| |    | | (_) | (_) | |
|___/\__\__,_|\__, |    |_|\___/ \___/|_|
               __/ |                     
              |___/                      
" -ForegroundColor Cyan

    for ($i = 0; $i -lt $opcoes.Count; $i++) {
        if ($i -eq $selecionado) {
            Write-Host " > $($opcoes[$i])" -ForegroundColor Yellow -BackgroundColor DarkCyan
        } else {
            Write-Host "   $($opcoes[$i])"
        }
    }

    $tecla = [Console]::ReadKey($true)

    switch ($tecla.Key) {
        "UpArrow" {
            $selecionado = ($selecionado - 1 + $opcoes.Count) % $opcoes.Count
        }
        "DownArrow" {
            $selecionado = ($selecionado + 1) % $opcoes.Count
        }
        "Enter" {
            $escolhaTexto = $opcoes[$selecionado]

            if ($escolhaTexto -eq "Sair") {
                $rodando = $false
            } else {
                $nomeArquivo = $mapaScripts[$escolhaTexto]
                $scriptPath = ".\$nomeArquivo.ps1"

                if (Test-Path $scriptPath) {
                    Clear-Host
                    Write-Host ">> Executando: $nomeArquivo.ps1`n" -ForegroundColor Cyan
                    
                    & $scriptPath
                    
                    Write-Host "`n`nPressione qualquer tecla para voltar..." -ForegroundColor Gray
                    [Console]::ReadKey($true) | Out-Null
                } else {
                    Write-Host "`n[!] Erro: Arquivo '$scriptPath' não encontrado." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
        }
    }
}

[Console]::CursorVisible = $true
Clear-Host
Write-Host "Script finalizado com sucesso." -ForegroundColor Green
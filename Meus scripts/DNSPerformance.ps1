$host.UI.RawUI.WindowTitle = "Analisador de Tempo de Resposta DNS 1.0.0 (Criador: Fabiopsyduck)"
[Console]::CursorVisible = $false

# Variável para controlar salvamento
$script:resultadosSalvos = $false
$script:arquivoNextDNS = "Meu_NextDNS.txt"

function Show-PreparationScreen {
    Clear-Host
    Write-Host @"
=============================================
         PREPARAÇÃO PARA O TESTE DNS
=============================================

PARA RESULTADOS MAIS PRECISOS, RECOMENDAMOS:

1. Evite atividades online durante o teste:
   - Navegação web
   - Streaming (YouTube, Netflix)
   - Downloads/uploads
   - Clientes torrent (qBittorrent, uTorrent, BitTorrent)
   - Jogos online (Steam, Epic Games)

2. Otimize sua conexão:
   - Use cabo de rede (evite Wi-Fi)
   - Desative VPNs
   - Desative antivírus temporariamente (opcional)
   - Desative apps que podem alterar ou manipular DNS

3. Reduza interferências:
   - Evite programas pesados (jogos, edição)
   - Certifique-se de que não há atualizações em andamento (Windows, Steam, Battle.net)

=============================================
"@ -ForegroundColor Cyan

    # Verifica se o arquivo NextDNS existe para definir a opção 3
    $opcaoNextDNS = if (Test-Path $script:arquivoNextDNS) {
        "Apagar DNS pessoal do NextDNS"
    } else {
        "Inserir seu DNS pessoal do NextDNS"
    }

    Write-Host "Pressione " -NoNewline
    Write-Host "1" -ForegroundColor Yellow -NoNewline
    Write-Host " para testar Servidores IPv4"
    
    Write-Host "Pressione " -NoNewline
    Write-Host "2" -ForegroundColor Green -NoNewline
    Write-Host " para testar Servidores IPv6"
    
    Write-Host "Pressione " -NoNewline
    Write-Host "3" -ForegroundColor Blue -NoNewline
    Write-Host " para $opcaoNextDNS"
    
    Write-Host "Pressione " -NoNewline
    Write-Host "V" -ForegroundColor Red -NoNewline
    Write-Host " para Sair" -NoNewline

    $tecla = $null
    while ($tecla -notin '1','2','3','V') {
        $tecla = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
        Start-Sleep -Milliseconds 100
    }

    if ($tecla -eq '1') {
        Clear-Host
        $script:resultadosSalvos = $false
        return 'IPv4'
    } 
    elseif ($tecla -eq '2') {
        Clear-Host
        $script:resultadosSalvos = $false
        return 'IPv6'
    }
    elseif ($tecla -eq '3') {
        Clear-Host
        if (Test-Path $script:arquivoNextDNS) {
            # Opção para APAGAR o DNS personalizado
            Write-Host "Tem certeza que deseja apagar o seu DNS pessoal? (s/n)" -ForegroundColor Yellow
            $confirmacao = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
            if ($confirmacao -eq 's') {
                Remove-Item $script:arquivoNextDNS -Force
                Write-Host "Arquivo removido com sucesso!" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
        } else {
            # Opção para INSERIR novo DNS personalizado
            Write-Host "Você tem uma conta no NextDNS? (s/n)" -ForegroundColor Yellow
            $temConta = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
            if ($temConta -eq 'n') {
                Write-Host "Gostaria de criar uma conta no NextDNS? (s/n)" -ForegroundColor Yellow
                $criarConta = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
                if ($criarConta -eq 's') {
                    Start-Process "https://nextdns.io"
                    Write-Host "Navegador aberto para cadastro. Pressione qualquer tecla para continuar..." -ForegroundColor Cyan
                    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
                }
            } else {
                # Coleta dos DNS personalizados
                $dnsIPv4Primario = Read-Host "Qual é o seu DNS primário IPv4?"
                $dnsIPv4Secundario = Read-Host "Qual é o seu DNS secundário IPv4?"
                $dnsIPv6Primario = Read-Host "Qual é o seu DNS primário IPv6?"
                $dnsIPv6Secundario = Read-Host "Qual é o seu DNS secundário IPv6?"

                # Salva no arquivo
                @"
IPv4_Primario=$dnsIPv4Primario
IPv4_Secundario=$dnsIPv4Secundario
IPv6_Primario=$dnsIPv6Primario
IPv6_Secundario=$dnsIPv6Secundario
"@ | Out-File -FilePath $script:arquivoNextDNS -Encoding UTF8

                Write-Host "DNS personalizado salvo com sucesso!" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
        }
        return Show-PreparationScreen  # Volta para a tela inicial
    }
    else {
        [Console]::CursorVisible = $true
        exit
    }
}

# Configurações comuns
$ErrorActionPreference = 'SilentlyContinue'
$dominioTeste = "google.com"
$quantidadeTestes = 100
$timeoutMs = 2000
$intervaloEntreTestesMs = 100

# Limites de latência
$limiteMediaAlta = 80
$limiteMaximoAlto = 120

# Esquema de cores
$corLatenciaOtima = [ConsoleColor]::DarkYellow
$corAltaLatencia = "Magenta"
$corErro = "Red"

# Servidores DNS IPv4 (REMOVIDOS os NextDNS padrão)
$servidoresDNSv4 = @(
    [PSCustomObject]@{Nome="Google Primário"; IP="8.8.8.8"},
    [PSCustomObject]@{Nome="Google Secundário"; IP="8.8.4.4"},
    [PSCustomObject]@{Nome="Quad9 Primário"; IP="9.9.9.9"},
    [PSCustomObject]@{Nome="Quad9 Secundário"; IP="149.112.112.112"},
    [PSCustomObject]@{Nome="Quad9 Security Primário"; IP="9.9.9.11"},
    [PSCustomObject]@{Nome="Quad9 Security Secundário"; IP="149.112.112.11"},
    [PSCustomObject]@{Nome="Quad9 Sem Proteção Primário"; IP="9.9.9.10"},
    [PSCustomObject]@{Nome="Quad9 Sem Proteção Secundário"; IP="149.112.112.10"},
    [PSCustomObject]@{Nome="Cloudflare Primário"; IP="1.1.1.1"},
    [PSCustomObject]@{Nome="Cloudflare Secundário"; IP="1.0.0.1"},
    [PSCustomObject]@{Nome="Cloudflare Security Primário"; IP="1.1.1.2"},
    [PSCustomObject]@{Nome="Cloudflare Security Secundário"; IP="1.0.0.2"},
    [PSCustomObject]@{Nome="AdGuard Primário"; IP="94.140.14.14"},
    [PSCustomObject]@{Nome="AdGuard Secundário"; IP="94.140.15.15"},
    [PSCustomObject]@{Nome="GigaDNS Primário"; IP="189.38.95.95"},
    [PSCustomObject]@{Nome="GigaDNS Secundário"; IP="189.38.95.96"},
    [PSCustomObject]@{Nome="Telefônica/Vivo 1 Primário"; IP="200.204.0.10"},
    [PSCustomObject]@{Nome="Telefônica/Vivo 1 Secundário"; IP="200.204.0.138"},
    [PSCustomObject]@{Nome="Telefônica/Vivo 2 Primário"; IP="200.205.125.58"},
    [PSCustomObject]@{Nome="Telefônica/Vivo 2 Secundário"; IP="200.205.125.57"},
    [PSCustomObject]@{Nome="Brisanet Primário"; IP="177.37.220.17"},
    [PSCustomObject]@{Nome="Brisanet Secundário"; IP="177.37.220.18"},
    [PSCustomObject]@{Nome="OpenDNS Primário"; IP="208.67.222.222"},
    [PSCustomObject]@{Nome="OpenDNS Secundário"; IP="208.67.220.220"},
    [PSCustomObject]@{Nome="OpenDNS 2 Primário"; IP="208.67.222.220"},
    [PSCustomObject]@{Nome="OpenDNS 2 Secundário"; IP="208.67.220.222"},
    [PSCustomObject]@{Nome="SafeDNS Primário"; IP="195.46.39.39"},
    [PSCustomObject]@{Nome="SafeDNS Secundário"; IP="195.46.39.40"},
    [PSCustomObject]@{Nome="DynDNS Primário"; IP="216.146.36.36"},
    [PSCustomObject]@{Nome="DynDNS Secundário"; IP="216.146.35.35"},
    [PSCustomObject]@{Nome="Verisign Primário"; IP="64.6.65.6"},
    [PSCustomObject]@{Nome="Verisign Secundário"; IP="64.6.64.6"},
    [PSCustomObject]@{Nome="UOL Primário"; IP="200.221.11.100"},
    [PSCustomObject]@{Nome="UOL Secundário"; IP="200.221.11.101"}
)

# Servidores DNS IPv6 (ADICIONADO suporte a NextDNS personalizado)
$servidoresDNSv6 = @(
    [PSCustomObject]@{Nome="Quad9 Primário"; IP="2620:fe::fe"},
    [PSCustomObject]@{Nome="Quad9 Secundário"; IP="2620:fe::9"},
    [PSCustomObject]@{Nome="Quad9 Security Primário"; IP="2620:fe::11"},
    [PSCustomObject]@{Nome="Quad9 Security Secundário"; IP="2620:fe::fe:11"},
    [PSCustomObject]@{Nome="Quad9 Sem Proteção Primário"; IP="2620:fe::10"},
    [PSCustomObject]@{Nome="Quad9 Sem Proteção Secundário"; IP="2620:fe::fe:10"},
    [PSCustomObject]@{Nome="Cloudflare Primário"; IP="2606:4700:4700::1111"},
    [PSCustomObject]@{Nome="Cloudflare Secundário"; IP="2606:4700:4700::1001"},
    [PSCustomObject]@{Nome="Cloudflare Security Primário"; IP="2606:4700:4700::1113"},
    [PSCustomObject]@{Nome="Cloudflare Security Secundário"; IP="2606:4700:4700::1003"},
    [PSCustomObject]@{Nome="OpenDNS Primário"; IP="2620:119:35::35"},
    [PSCustomObject]@{Nome="OpenDNS Secundário"; IP="2620:119:53::53"},
    [PSCustomObject]@{Nome="AdGuard Primário"; IP="2a10:50c0::ad1:ff"},
    [PSCustomObject]@{Nome="AdGuard Secundário"; IP="2a10:50c0::ad2:ff"},
    [PSCustomObject]@{Nome="AdGuard Sem Filtro Primário"; IP="2a10:50c0::1:ff"},
    [PSCustomObject]@{Nome="AdGuard Sem Filtro Secundário"; IP="2a10:50c0::2:ff"},
    [PSCustomObject]@{Nome="GigaDNS Primário"; IP="2804:10:10::10"},
    [PSCustomObject]@{Nome="GigaDNS Secundário"; IP="2804:10:10::20"},
    [PSCustomObject]@{Nome="Brisanet Primário"; IP="2804:29b8:1000:1::17"},
    [PSCustomObject]@{Nome="Brisanet Secundário"; IP="2804:29b8:1000:1::18"},
    [PSCustomObject]@{Nome="Google Primário"; IP="2001:4860:4860::8888"},
    [PSCustomObject]@{Nome="Google Secundário"; IP="2001:4860:4860::8844"},
    [PSCustomObject]@{Nome="SafeDNS Primário"; IP="2001:67c:2778::3939"},
    [PSCustomObject]@{Nome="SafeDNS Secundário"; IP="2001:67c:2778::3940"}
)

#Nota da "function Testar-DNSServer"
#ATENÇÃO: Esta função contém lógica crítica para o NextDNS!
#Não modificar os parâmetros [ref]$testesRealizados e $cursorTop
#Manter a estrutura try/catch que detecta falhas no DNS
function Testar-DNSServer {
    param (
        $servidor, 
        $tipoTeste,
        [ref]$cancelado
    )
    
    $tempos = @()
    
    for ($i = 1; $i -le $quantidadeTestes; $i++) {
        if ([Console]::KeyAvailable) {
            $tecla = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
            if ($tecla -eq 'V') {
                $cancelado.Value = $true
                return $null
            }
        }

        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = Resolve-DnsName -Name $dominioTeste -Server $servidor.IP -DnsOnly -QuickTimeout -ErrorAction Stop
            $sw.Stop()
            $tempos += $sw.Elapsed.TotalMilliseconds
            Start-Sleep -Milliseconds $intervaloEntreTestesMs
        }
        catch {
            return [PSCustomObject]@{
                Nome = $servidor.Nome
                IP = $servidor.IP
                Minimo = "--------"
                MediaMinima = "--------"
                Media = "--------"
                MediaMaxima = "--------"
                Maximo = "--------"
            }
        }
    }
    
    if ($tempos.Count -eq 0) {
        return [PSCustomObject]@{
            Nome = $servidor.Nome
            IP = $servidor.IP
            Minimo = "--------"
            MediaMinima = "--------"
            Media = "--------"
            MediaMaxima = "--------"
            Maximo = "--------"
        }
    }
    
    $media = ($tempos | Measure-Object -Average).Average
    $valoresAbaixoMedia = $tempos | Where-Object { $_ -lt $media }
    $valoresAcimaMedia = $tempos | Where-Object { $_ -gt $media }
    
    $mediaMinima = "--------"
    if ($valoresAbaixoMedia.Count -gt 0) {
        $mediaMinima = [math]::Round(($valoresAbaixoMedia | Measure-Object -Average).Average, 2)
    }
    
    $mediaMaxima = "--------"
    if ($valoresAcimaMedia.Count -gt 0) {
        $mediaMaxima = [math]::Round(($valoresAcimaMedia | Measure-Object -Average).Average, 2)
    }
    
    return [PSCustomObject]@{
        Nome = $servidor.Nome
        IP = $servidor.IP
        Minimo = [math]::Round(($tempos | Measure-Object -Minimum).Minimum, 2)
        MediaMinima = if ($mediaMinima -eq "--------") { "--------" } else { "$mediaMinima ms" }
        Media = [math]::Round($media, 2)
        MediaMaxima = if ($mediaMaxima -eq "--------") { "--------" } else { "$mediaMaxima ms" }
        Maximo = [math]::Round(($tempos | Measure-Object -Maximum).Maximum, 2)
    }
}

function Get-MelhorGrupoDNS {
    param ($resultados, $tipoDNS)
    
    if ($tipoDNS -eq 'IPv4') {
        $gruposDNS = @{
            "Google" = @{ Primario = "8.8.8.8"; Secundario = "8.8.4.4" }
            "Quad9" = @{ Primario = "9.9.9.9"; Secundario = "149.112.112.112" }
            "Quad9 Security" = @{ Primario = "9.9.9.11"; Secundario = "149.112.112.11" }
            "Quad9 Sem Proteção" = @{ Primario = "9.9.9.10"; Secundario = "149.112.112.10" }
            "Cloudflare" = @{ Primario = "1.1.1.1"; Secundario = "1.0.0.1" }
            "Cloudflare Security" = @{ Primario = "1.1.1.2"; Secundario = "1.0.0.2" }
            "AdGuard" = @{ Primario = "94.140.14.14"; Secundario = "94.140.15.15" }
            "GigaDNS" = @{ Primario = "189.38.95.95"; Secundario = "189.38.95.96" }
            "Telefônica/Vivo" = @{ Primario = "200.204.0.10"; Secundario = "200.204.0.138" }
            "Telefônica/Vivo 2" = @{ Primario = "200.205.125.58"; Secundario = "200.205.125.57" }
            "Brisanet" = @{ Primario = "177.37.220.17"; Secundario = "177.37.220.18" }
            "OpenDNS" = @{ Primario = "208.67.222.222"; Secundario = "208.67.220.220" }
            "OpenDNS 2" = @{ Primario = "208.67.222.220"; Secundario = "208.67.220.222" }
            "SafeDNS" = @{ Primario = "195.46.39.39"; Secundario = "195.46.39.40" }
            "DynDNS" = @{ Primario = "216.146.36.36"; Secundario = "216.146.35.35" }
            "Verisign" = @{ Primario = "64.6.65.6"; Secundario = "64.6.64.6" }
            "UOL" = @{ Primario = "200.221.11.100"; Secundario = "200.221.11.101" }
        }
    }
    else {
        $gruposDNS = @{
            "Quad9" = @{ Primario = "2620:fe::fe"; Secundario = "2620:fe::9" }
            "Quad9 Security" = @{ Primario = "2620:fe::11"; Secundario = "2620:fe::fe:11" }
            "Quad9 Sem Proteção" = @{ Primario = "2620:fe::10"; Secundario = "2620:fe::fe:10" }
            "Cloudflare" = @{ Primario = "2606:4700:4700::1111"; Secundario = "2606:4700:4700::1001" }
            "Cloudflare Security" = @{ Primario = "2606:4700:4700::1113"; Secundario = "2606:4700:4700::1003" }
            "OpenDNS" = @{ Primario = "2620:119:35::35"; Secundario = "2620:119:53::53" }
            "AdGuard" = @{ Primario = "2a10:50c0::ad1:ff"; Secundario = "2a10:50c0::ad2:ff" }
            "AdGuard Sem Filtro" = @{ Primario = "2a10:50c0::1:ff"; Secundario = "2a10:50c0::2:ff" }
            "GigaDNS" = @{ Primario = "2804:10:10::10"; Secundario = "2804:10:10::20" }
            "Brisanet" = @{ Primario = "2804:29b8:1000:1::17"; Secundario = "2804:29b8:1000:1::18" }
            "Google" = @{ Primario = "2001:4860:4860::8888"; Secundario = "2001:4860:4860::8844" }
            "SafeDNS" = @{ Primario = "2001:67c:2778::3939"; Secundario = "2001:67c:2778::3940" }
        }
    }
    
    # Adiciona NextDNS personalizado se o arquivo existir
    if (Test-Path $script:arquivoNextDNS) {
        $dados = Get-Content $script:arquivoNextDNS | ConvertFrom-StringData
        if ($tipoDNS -eq 'IPv4') {
            $gruposDNS["NextDNS Personalizado"] = @{
                Primario = $dados.IPv4_Primario
                Secundario = $dados.IPv4_Secundario
            }
        } else {
            $gruposDNS["NextDNS Personalizado"] = @{
                Primario = $dados.IPv6_Primario
                Secundario = $dados.IPv6_Secundario
            }
        }
    }
    
    $gruposAvaliados = @()
    foreach ($grupo in $gruposDNS.Keys) {
        $primario = $resultados | Where-Object { $_.IP -eq $gruposDNS[$grupo].Primario -and $_.Media -ne "--------" }
        $secundario = $resultados | Where-Object { $_.IP -eq $gruposDNS[$grupo].Secundario -and $_.Media -ne "--------" }
        
        if ($primario -and $secundario) {
            # Converte "MediaMaxima" de string (ex: "50 ms") para número (50)
            $mediaMaximaPrimario = if ($primario.MediaMaxima -eq "--------") { 0 } else { [double]($primario.MediaMaxima -replace " ms", "") }
            $mediaMaximaSecundario = if ($secundario.MediaMaxima -eq "--------") { 0 } else { [double]($secundario.MediaMaxima -replace " ms", "") }
            
            # Calcula médias combinadas
            $mediaCombinada = ($primario.Media + $secundario.Media) / 2
            $mediaMaximaCombinada = ($mediaMaximaPrimario + $mediaMaximaSecundario) / 2
            $maximoCombinado = ($primario.Maximo + $secundario.Maximo) / 2
            
            # Fórmula de pontuação com pesos 60-20-20
            $pontuacao = ($mediaCombinada * 0.6) + ($mediaMaximaCombinada * 0.2) + ($maximoCombinado * 0.2)
            
            $gruposAvaliados += [PSCustomObject]@{
                Nome = $grupo
                Primario = $gruposDNS[$grupo].Primario
                Secundario = $gruposDNS[$grupo].Secundario
                MediaCombinada = [math]::Round($mediaCombinada, 2)
                MediaMaximaCombinada = [math]::Round($mediaMaximaCombinada, 2)
                MaximoCombinado = [math]::Round($maximoCombinado, 2)
                Pontuacao = [math]::Round($pontuacao, 2)
            }
        }
    }
    
    # Ordena por pontuação (menor = melhor)
    $gruposAvaliados | Sort-Object Pontuacao
}

function Save-ResultsToFile {
    param ($resultados, $tipoTeste)
    
    $dataAtual = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $nomeArquivo = "Resultado_${tipoTeste}_${dataAtual}.txt"
    
    $conteudo = @()
    $conteudo += "TESTE DE DNS $tipoTeste (100 TESTES POR SERVIDOR)`n"
    $conteudo += "=== Resultados ===`n`n"
    $conteudo += ("Nome".PadRight(31) + "IP".PadRight(26) + "Mínimo".PadRight(13) + "Média-Mín".PadRight(13) + "Média".PadRight(13) + "Média-Máx".PadRight(13) + "Máximo")
    $conteudo += "------------------------------ ------------------------  ----------   -----------  ----------   -----------  -----------"
    
    foreach ($resultado in $resultados) {
        $minimo = if ($resultado.Minimo -eq "--------") { "--------" } else { $resultado.Minimo.ToString("0.00") + " ms" }
        $mediaMinima = $resultado.MediaMinima
        $media = if ($resultado.Media -eq "--------") { "--------" } else { $resultado.Media.ToString("0.00") + " ms" }
        $maximo = if ($resultado.Maximo -eq "--------") { "--------" } else { $resultado.Maximo.ToString("0.00") + " ms" }
        
        $conteudo += $resultado.Nome.PadRight(30) + " " + $resultado.IP.PadRight(25) + " " +
                     $minimo.PadRight(12) + " " + $mediaMinima.PadRight(12) + " " +
                     $media.PadRight(12) + " " + $resultado.MediaMaxima.PadRight(12) + " " + $maximo
    }
    
    $conteudo += "`nLEGENDA:"
    $conteudo += " BAIXA LATÊNCIA  (Média ≤60 ms e Máximo <130 ms e Média-Máxima <80 ms)"
    $conteudo += " ALTA LATÊNCIA   (Média ≥80 ms ou Média-Máxima ≥80 ms ou Máximo ≥130 ms)"
    $conteudo += " ERRO            (Servidor ignorado por apresentar falha)"
    
    $melhoresGrupos = Get-MelhorGrupoDNS -resultados $resultados -tipoDNS $tipoTeste | Select-Object -First 2
    $melhorGrupo = $melhoresGrupos[0]
    $segundoMelhorGrupo = $melhoresGrupos[1]
    
    $conteudo += "`nDNS com a melhor performance em geral:"
    if ($melhorGrupo) {
        $conteudo += ("Nome do dns".PadRight(18) + ": $($melhorGrupo.Nome)")
        $conteudo += ("DNS Primário".PadRight(18) + ": $($melhorGrupo.Primario)")
        $conteudo += ("DNS Secundário".PadRight(18) + ": $($melhorGrupo.Secundario)")
    }
    
    $conteudo += "`nDNS alternativa com a melhor performance em geral:"
    if ($segundoMelhorGrupo) {
        $conteudo += ("Nome do dns".PadRight(18) + ": $($segundoMelhorGrupo.Nome)")
        $conteudo += ("DNS Primário".PadRight(18) + ": $($segundoMelhorGrupo.Primario)")
        $conteudo += ("DNS Secundário".PadRight(18) + ": $($segundoMelhorGrupo.Secundario)")
    } else {
        $conteudo += "Nenhuma alternativa disponível com ambos servidores respondendo"
    }
    
    $conteudo | Out-File -FilePath $nomeArquivo -Encoding UTF8
    $script:resultadosSalvos = $true
}

function Show-Results {
    param ($resultados, $tipoTeste)
    
    function Show-ResultadosTable {
        param ($resultados)
        
        Write-Host ("Nome".PadRight(31) + "IP".PadRight(26) + "Mínimo".PadRight(13) + "Média-Mín".PadRight(13) + "Média".PadRight(13) + "Média-Máx".PadRight(13) + "Máximo")
        Write-Host "------------------------------ ------------------------  ----------   -----------  ----------   -----------  -----------"
        
        foreach ($resultado in $resultados) {
            $minimo = if ($resultado.Minimo -eq "--------") { "--------" } else { $resultado.Minimo.ToString("0.00") + " ms" }
            $mediaMinima = $resultado.MediaMinima
            $media = if ($resultado.Media -eq "--------") { "--------" } else { $resultado.Media.ToString("0.00") + " ms" }
            $mediaMaxima = $resultado.MediaMaxima
            $maximo = if ($resultado.Maximo -eq "--------") { "--------" } else { $resultado.Maximo.ToString("0.00") + " ms" }
            
            $linha = $resultado.Nome.PadRight(30) + " " + $resultado.IP.PadRight(25) + " " +
                     $minimo.PadRight(12) + " " + $mediaMinima.PadRight(12) + " " +
                     $media.PadRight(12) + " " + $mediaMaxima.PadRight(12) + " " + $maximo
            
            if ($resultado.Media -eq "--------") {
                Write-Host $linha -ForegroundColor $corErro
            }
            elseif ($resultado.Media -le 60 -and $resultado.Maximo -lt 130 -and ($resultado.MediaMaxima -eq "--------" -or [double]$resultado.MediaMaxima.Replace(" ms","") -lt 80)) {
                Write-Host $linha -ForegroundColor $corLatenciaOtima
            }
            elseif ($resultado.Media -ge 80 -or ($resultado.MediaMaxima -ne "--------" -and [double]$resultado.MediaMaxima.Replace(" ms","") -ge 80) -or $resultado.Maximo -ge 130) {
                Write-Host $linha -ForegroundColor $corAltaLatencia
            }
            else {
                Write-Host $linha
            }
        }
    }

    Clear-Host
    Write-Host "TESTE DE DNS $tipoTeste (100 TESTES POR SERVIDOR)`n"
    Write-Host "=== Resultados ===`n"
    Show-ResultadosTable -resultados $resultados

    Write-Host "`nLEGENDA:"
    Write-Host " BAIXA LATÊNCIA  " -NoNewline -ForegroundColor $corLatenciaOtima
    Write-Host "(Média ≤60 ms e Máximo <130 ms e Média-Máxima <80 ms)"
    Write-Host " ALTA LATÊNCIA   " -NoNewline -ForegroundColor $corAltaLatencia
    Write-Host "(Média ≥80 ms ou Média-Máxima ≥80 ms ou Máximo ≥130 ms)"
    Write-Host " ERRO            " -NoNewline -ForegroundColor $corErro
    Write-Host "(Servidor ignorado por apresentar falha)"

    $melhoresGrupos = Get-MelhorGrupoDNS -resultados $resultados -tipoDNS $tipoTeste | Select-Object -First 2
    $melhorGrupo = $melhoresGrupos[0]
    $segundoMelhorGrupo = $melhoresGrupos[1]

    Write-Host "`nDNS com a melhor performance em geral:"
    if ($melhorGrupo) {
        Write-Host ("Nome do dns".PadRight(18) + ": $($melhorGrupo.Nome)")
        Write-Host ("DNS Primário".PadRight(18) + ": $($melhorGrupo.Primario)")
        Write-Host ("DNS Secundário".PadRight(18) + ": $($melhorGrupo.Secundario)")
    }

    Write-Host "`nDNS alternativa com a melhor performance em geral:"
    if ($segundoMelhorGrupo) {
        Write-Host ("Nome do dns".PadRight(18) + ": $($segundoMelhorGrupo.Nome)")
        Write-Host ("DNS Primário".PadRight(18) + ": $($segundoMelhorGrupo.Primario)")
        Write-Host ("DNS Secundário".PadRight(18) + ": $($segundoMelhorGrupo.Secundario)")
    } else {
        Write-Host "Nenhuma alternativa disponível com ambos servidores respondendo"
    }

    if (-not $script:resultadosSalvos) {
        Write-Host "`nPressione 's' para salvar resultados"
    }
    Write-Host "Pressione 'v' para voltar" -NoNewline
    
    [Console]::SetCursorPosition(0, 0)

    do {
        $tecla = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
        if ($tecla -eq 's' -and -not $script:resultadosSalvos) {
            Save-ResultsToFile -resultados $resultados -tipoTeste $tipoTeste
            
            Clear-Host
            Write-Host "TESTE DE DNS $tipoTeste (100 TESTES POR SERVIDOR)`n"
            Write-Host "=== Resultados ===`n"
            Show-ResultadosTable -resultados $resultados
            
            Write-Host "`nLEGENDA:"
            Write-Host " BAIXA LATÊNCIA  " -NoNewline -ForegroundColor $corLatenciaOtima
            Write-Host "(Média ≤60 ms e Máximo <130 ms e Média-Máxima <80 ms)"
            Write-Host " ALTA LATÊNCIA   " -NoNewline -ForegroundColor $corAltaLatencia
            Write-Host "(Média ≥80 ms ou Média-Máxima ≥80 ms ou Máximo ≥130 ms)"
            Write-Host " ERRO            " -NoNewline -ForegroundColor $corErro
            Write-Host "(Servidor ignorado por apresentar falha)"
            
            Write-Host "`nDNS com a melhor performance em geral:"
            if ($melhorGrupo) {
                Write-Host ("Nome do dns".PadRight(18) + ": $($melhorGrupo.Nome)")
                Write-Host ("DNS Primário".PadRight(18) + ": $($melhorGrupo.Primario)")
                Write-Host ("DNS Secundário".PadRight(18) + ": $($melhorGrupo.Secundario)")
            }

            Write-Host "`nDNS alternativa com a melhor performance em geral:"
            if ($segundoMelhorGrupo) {
                Write-Host ("Nome do dns".PadRight(18) + ": $($segundoMelhorGrupo.Nome)")
                Write-Host ("DNS Primário".PadRight(18) + ": $($segundoMelhorGrupo.Primario)")
                Write-Host ("DNS Secundário".PadRight(18) + ": $($segundoMelhorGrupo.Secundario)")
            }

            Write-Host "`nPressione 'v' para voltar" -NoNewline
            [Console]::SetCursorPosition(0, 0)
        }
    } while ($tecla -ne 'v')

    Clear-Host
}

# Execução principal
######################################################
# ATENÇÃO: BLOCO SENSÍVEL - INTEGRAÇÃO NEXTDNS
# - As variáveis $dadosNextDNS devem seguir o formato:
#   IPv4_Primario=xxx.xxx.xxx.xxx
#   IPv4_Secundario=xxx.xxx.xxx.xxx
#   IPv6_Primario=xxxx::xxxx
# - Não alterar a estrutura if/else de validação
######################################################
do {
    $tipoTeste = Show-PreparationScreen
    
    # Carrega servidores base com clone para não modificar as listas originais
    $servidoresTeste = if ($tipoTeste -eq 'IPv4') { 
        $servidoresDNSv4.Clone()
    } else { 
        $servidoresDNSv6.Clone()
    }

    # Adiciona NextDNS personalizado se o arquivo existir
    if (Test-Path $script:arquivoNextDNS) {
        $dadosNextDNS = Get-Content $script:arquivoNextDNS | ConvertFrom-StringData
        
        if ($tipoTeste -eq 'IPv4') {
            if (-not [string]::IsNullOrWhiteSpace($dadosNextDNS.IPv4_Primario)) {
                $servidoresTeste += [PSCustomObject]@{
                    Nome = "NextDNS Pessoal Primário"
                    IP = $dadosNextDNS.IPv4_Primario
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($dadosNextDNS.IPv4_Secundario)) {
                $servidoresTeste += [PSCustomObject]@{
                    Nome = "NextDNS Pessoal Secundário"
                    IP = $dadosNextDNS.IPv4_Secundario
                }
            }
        } else {
            if (-not [string]::IsNullOrWhiteSpace($dadosNextDNS.IPv6_Primario)) {
                $servidoresTeste += [PSCustomObject]@{
                    Nome = "NextDNS Pessoal Primário"
                    IP = $dadosNextDNS.IPv6_Primario
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($dadosNextDNS.IPv6_Secundario)) {
                $servidoresTeste += [PSCustomObject]@{
                    Nome = "NextDNS Pessoal Secundário"
                    IP = $dadosNextDNS.IPv6_Secundario
                }
            }
        }
    }

    $totalServidores = $servidoresTeste.Count
    $servidoresProcessados = 0

    Clear-Host
    Write-Host "TESTE DE DNS $tipoTeste (100 TESTES POR SERVIDOR)`n"
    Write-Host "=== Resultados ===`n"

    # Posiciona o cursor para as mensagens de progresso
    $cursorTop = [Console]::CursorTop
    
    # Variável para controlar o cancelamento
    $cancelado = $false

    $resultados = @()
    foreach ($servidor in $servidoresTeste) {
        # Atualiza o progresso ANTES do teste
        $servidoresProcessados++
        [Console]::SetCursorPosition(0, $cursorTop)
        Write-Host "Progresso: ( $servidoresProcessados / $totalServidores )        "

        # Mostra mensagem de cancelamento apenas se não terminou
        if ($servidoresProcessados -lt $totalServidores -and !$cancelado) {
            [Console]::SetCursorPosition(0, $cursorTop + 1)
            Write-Host (" " * 50) -NoNewline
            [Console]::SetCursorPosition(0, $cursorTop + 1)
            Write-Host "(Pressione V para cancelar e voltar)" -NoNewline
        }
        else {
            [Console]::SetCursorPosition(0, $cursorTop + 1)
            Write-Host (" " * 50) -NoNewline
        }

        # Executa o teste com verificação de cancelamento
        $resultado = Testar-DNSServer -servidor $servidor -tipoTeste $tipoTeste -cancelado ([ref]$cancelado)
        
        # Verifica se foi cancelado
        if ($cancelado -or $null -eq $resultado) {
            [Console]::SetCursorPosition(0, $cursorTop + 1)
            Write-Host (" " * 50) -NoNewline
            [Console]::SetCursorPosition(0, $cursorTop + 1)
            Write-Host "Cancelando teste..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
            break
        }
        
        $resultados += $resultado
    }

    # Limpa a mensagem de progresso imediatamente (delay removido)
    [Console]::SetCursorPosition(0, $cursorTop + 1)
    Write-Host (" " * 50) -NoNewline

    # Só mostrar resultados se não foi cancelado e terminou
    if (!$cancelado -and $servidoresProcessados -eq $totalServidores) {
        Show-Results -resultados $resultados -tipoTeste $tipoTeste
    }
} while ($true)

# Configurar a codificação UTF-8 para entrada e saída
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Ocultar o cursor do console
[Console]::CursorVisible = $false

# Ignorar combinações de teclas como Ctrl+C
[Console]::TreatControlCAsInput = $true

# Define o título da janela do PowerShell
$host.ui.RawUI.WindowTitle = "Monitor de Desempenho"

# Adiciona código C# ao PowerShell para manipular janelas do Windows
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_SHOWWINDOW = 0x0040;
}
"@ -Language CSharp

# Obtém a janela do script atual
$hWnd = [WinAPI]::GetForegroundWindow()

# Mantém a janela sempre no topo
[void][WinAPI]::SetWindowPos($hWnd, [WinAPI]::HWND_TOPMOST, 0, 0, 0, 0, [WinAPI]::SWP_NOSIZE -bor [WinAPI]::SWP_NOMOVE -bor [WinAPI]::SWP_SHOWWINDOW)

# Adiciona código C# para manipular tamanho e estilo da janela
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern long SetWindowLong(IntPtr hWnd, int nIndex, long dwNewLong);
    [DllImport("user32.dll")]
    public static extern long GetWindowLong(IntPtr hWnd, int nIndex);
}
"@ -Language CSharp

Start-Sleep -Milliseconds 500  # Aguarda um pouco para garantir que a janela abriu

# Obtém a janela atual
$janela = [Win32]::GetForegroundWindow()

# Define a largura e altura da janela (970 x 135 pixels)
[Win32]::MoveWindow($janela, 200, 200, 970, 135, $true)

# Impede o redimensionamento da janela e bloqueia o botão de maximizar
$GWL_STYLE = -16
$WS_SIZEBOX = 0x00040000  # Permite redimensionamento da janela
$WS_MAXIMIZEBOX = 0x00010000  # Habilita o botão de maximizar
$estiloAtual = [Win32]::GetWindowLong($janela, $GWL_STYLE)
$novoEstilo = $estiloAtual -band (-bnot ($WS_SIZEBOX -bor $WS_MAXIMIZEBOX))
[Win32]::SetWindowLong($janela, $GWL_STYLE, $novoEstilo)  # Remove o botão de maximizar e impede redimensionamento manual

# Remove as barras de rolagem do console
$host.UI.RawUI.BufferSize = $host.UI.RawUI.WindowSize


# Função para exibir uma barra de progresso com cores
function Show-ProgressBar {
    param (
        [float]$Value,
        [int]$Length = 20
    )

    $percent = [math]::Round($Value)
    $filled = [math]::Round($Value * $Length / 100)
    $bar = ('█' * $filled) + ('░' * ($Length - $filled))

    # Definir a cor com base no valor (mesmo esquema do monitorv30v2.ps1)
    if ($Value -ge 90) {
        $color = "Red"
    } elseif ($Value -ge 80) {
        $color = "Yellow"
    } else {
        $color = "White"
    }

    return @{
        Bar   = "[$bar]"
        Color = $color
    }
}

# Função para obter o uso da CPU
function Get-CpuUsage {
    try {
        $cpuUsage = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
        return [math]::Round($cpuUsage)  # Arredonda para número inteiro
    } catch {
        return "N/A"  # Retorna "N/A" se houver erro
    }
}

# Função para obter informações sobre a GPU (NVIDIA)
function Get-GpuInfo {
    try {
        # Executa o nvidia-smi uma vez e captura todas as métricas necessárias
        $gpuQuery = nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits
        $gpuData = $gpuQuery -split ","

        # Extrai os valores
        $gpuUsage = [math]::Round($gpuData[0].Trim())  # Uso da GPU em porcentagem
        $usedMemoryMB = [math]::Round($gpuData[1].Trim())  # Memória usada em MB
        $totalMemoryMB = [math]::Round($gpuData[2].Trim())  # Memória total em MB
        $freeMemoryMB = $totalMemoryMB - $usedMemoryMB  # Memória livre em MB
        $gpuTemp = [math]::Round($gpuData[3].Trim())  # Temperatura da GPU em Celsius

        # Calcular a porcentagem de uso da memória da GPU
        $gpuMemoryUsage = ($usedMemoryMB / $totalMemoryMB) * 100
        $gpuMemoryUsage = [math]::Round($gpuMemoryUsage)  # Arredonda para número inteiro

        return @{
            Usage         = $gpuUsage
            UsedMB        = $usedMemoryMB
            TotalMB       = $totalMemoryMB
            FreeMB        = $freeMemoryMB
            MemoryUsage   = $gpuMemoryUsage
            Temp          = $gpuTemp
        }
    } catch {
        # Retornar valores padrão em caso de erro
        return @{
            Usage         = "N/A"
            UsedMB        = "N/A"
            TotalMB       = "N/A"
            FreeMB        = "N/A"
            MemoryUsage   = "N/A"
            Temp          = "N/A"
        }
    }
}

# Função para obter informações sobre a RAM
function Get-RamInfo {
    try {
        $ram = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $totalMemoryKB = $ram.TotalVisibleMemorySize
        $freeMemoryKB = $ram.FreePhysicalMemory
        $usedMemoryKB = $totalMemoryKB - $freeMemoryKB

        # Converter KB para MB
        $totalMemoryMB = [math]::Round($totalMemoryKB / 1KB)  # Arredonda para número inteiro
        $usedMemoryMB = [math]::Round($usedMemoryKB / 1KB)    # Arredonda para número inteiro
        $freeMemoryMB = [math]::Round($freeMemoryKB / 1KB)    # Arredonda para número inteiro

        # Calcular a porcentagem de uso
        $ramUsage = ($usedMemoryKB / $totalMemoryKB) * 100
        $ramUsage = [math]::Round($ramUsage)  # Arredonda para número inteiro

        return @{
            TotalMB = $totalMemoryMB
            UsedMB  = $usedMemoryMB
            FreeMB  = $freeMemoryMB
            Usage   = $ramUsage
        }
    } catch {
        # Retornar valores padrão em caso de erro
        return @{
            TotalMB = "N/A"
            UsedMB  = "N/A"
            FreeMB  = "N/A"
            Usage   = "N/A"
        }
    }
}

# Exibir cabeçalhos (fixos)
Clear-Host
Write-Host ("CPU Usage:".PadRight(30) + "RAM Usage:".PadRight(30) + "GPU Usage:".PadRight(30) + "GPU Memory Usage:")

# Loop para atualizar as informações em tempo real
try {
    while ($true) {
        # Obter os dados
        $cpuUsage = Get-CpuUsage
        $ramInfo = Get-RamInfo
        $gpuInfo = Get-GpuInfo

        # Gerar as barras de progresso
        $cpuBar = Show-ProgressBar -Value $cpuUsage
        $ramBar = Show-ProgressBar -Value $ramInfo.Usage
        $gpuBar = Show-ProgressBar -Value $gpuInfo.Usage
        $gpuMemoryBar = Show-ProgressBar -Value $gpuInfo.MemoryUsage

        # Exibir barras de progresso e valores
        [Console]::SetCursorPosition(0, 1)
        Write-Host ("{0,3}% " -f $cpuUsage) -NoNewline
        Write-Host $cpuBar.Bar -ForegroundColor $cpuBar.Color

        [Console]::SetCursorPosition(30, 1)
        Write-Host ("{0,3}% " -f $ramInfo.Usage) -NoNewline
        Write-Host $ramBar.Bar -ForegroundColor $ramBar.Color

        [Console]::SetCursorPosition(60, 1)
        Write-Host ("{0,3}% " -f $gpuInfo.Usage) -NoNewline
        Write-Host $gpuBar.Bar -ForegroundColor $gpuBar.Color

        [Console]::SetCursorPosition(90, 1)
        Write-Host ("{0,3}% " -f $gpuInfo.MemoryUsage) -NoNewline
        Write-Host $gpuMemoryBar.Bar -ForegroundColor $gpuMemoryBar.Color

        # Exibir detalhes da RAM
        [Console]::SetCursorPosition(30, 2)
        Write-Host ("Used: {0,6} MB" -f $ramInfo.UsedMB).PadRight(30)

        [Console]::SetCursorPosition(30, 3)
        Write-Host ("Free: {0,6} MB" -f $ramInfo.FreeMB).PadRight(30)

        # Exibir detalhes da GPU
        [Console]::SetCursorPosition(60, 2)
        Write-Host ("Temp: {0,3}C" -f $gpuInfo.Temp).PadRight(30)

        # Exibir detalhes da memória da GPU
        [Console]::SetCursorPosition(90, 2)
        Write-Host ("Used: {0,6} MB" -f $gpuInfo.UsedMB).PadRight(30)

        [Console]::SetCursorPosition(90, 3)
        Write-Host ("Free: {0,6} MB" -f $gpuInfo.FreeMB).PadRight(30)

        # Reduzir o atraso para 1 milissegundo (praticamente imperceptível)
        Start-Sleep -Milliseconds 1
    }
} finally {
    # Restaurar a visibilidade do cursor ao finalizar o script
    [Console]::CursorVisible = $true
    # Restaurar o comportamento padrão do Ctrl+C
    [Console]::TreatControlCAsInput = $false
}
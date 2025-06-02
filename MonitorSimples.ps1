# Configuração do console
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false
[Console]::TreatControlCAsInput = $true
$host.ui.RawUI.WindowTitle = "Monitor Simples"

# Código C# para fixar a janela no topo e redimensionar
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

$hWnd = [WinAPI]::GetForegroundWindow()
[void][WinAPI]::SetWindowPos($hWnd, [WinAPI]::HWND_TOPMOST, 0, 0, 0, 0, [WinAPI]::SWP_NOSIZE -bor [WinAPI]::SWP_NOMOVE -bor [WinAPI]::SWP_SHOWWINDOW)

# Código C# para ajustar tamanho e bloquear redimensionamento
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

Start-Sleep -Milliseconds 500
$janela = [Win32]::GetForegroundWindow()

# **Define o tamanho correto da janela (540 x 70 pixels)**
[void][Win32]::MoveWindow($janela, 200, 200, 540, 70, $true)

# Impede o redimensionamento lateral e bloqueia maximizar
$GWL_STYLE = -16
$WS_SIZEBOX = 0x00040000  # Permite redimensionamento da janela
$WS_MAXIMIZEBOX = 0x00010000  # Habilita o botão de maximizar
$estiloAtual = [Win32]::GetWindowLong($janela, $GWL_STYLE)
$novoEstilo = $estiloAtual -band (-bnot ($WS_SIZEBOX -bor $WS_MAXIMIZEBOX))
[void][Win32]::SetWindowLong($janela, $GWL_STYLE, $novoEstilo)  # Remove botão de maximizar e impede redimensionamento manual

# **Ajuste correto do tamanho do buffer e da janela**
$bufferWidth = 64  # **Largura aumentada para caber o texto**
$bufferHeight = 1  # **Altura aumentada para evitar corte**
$windowWidth = 64
$windowHeight = 1

# Ordem correta para evitar erro
$host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size ($windowWidth, $windowHeight)
$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size ($bufferWidth, $bufferHeight)

# **Força remoção da barra de rolagem redefinindo o BufferSize**
Start-Sleep -Milliseconds 200
$host.UI.RawUI.BufferSize = $host.UI.RawUI.WindowSize


# Função para obter o uso da CPU
function Get-CpuUsage {
    try {
        return (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
    } catch { return "N/A" }
}

# Função para obter informações da GPU (NVIDIA)
function Get-GpuInfo {
    try {
        $gpuQuery = nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
        $gpuData = $gpuQuery -split ","
        return @{
            Usage   = [math]::Round($gpuData[0].Trim())
            UsedMB  = [math]::Round($gpuData[1].Trim())
            TotalMB = [math]::Round($gpuData[2].Trim())
        }
    } catch { return @{ Usage = "N/A"; UsedMB = "N/A"; TotalMB = "N/A" } }
}

# Função para obter informações da RAM
function Get-RamInfo {
    try {
        $ram = Get-CimInstance Win32_OperatingSystem
        $totalMB = [math]::Round($ram.TotalVisibleMemorySize / 1KB)
        $usedMB = [math]::Round(($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / 1KB)
        return @{ TotalMB = $totalMB; UsedMB = $usedMB }
    } catch { return @{ TotalMB = "N/A"; UsedMB = "N/A" } }
}

# Loop de monitoramento
while ($true) {
    $cpu = Get-CpuUsage
    $gpu = Get-GpuInfo
    $ram = Get-RamInfo

    $gpuUsage = if ($gpu.Usage -eq "N/A") { "N/A" } else { "$($gpu.Usage)%".PadLeft(3) }
    $ramUsage = if ($ram.TotalMB -eq "N/A") { "N/A" } else { "$([math]::Round(($ram.UsedMB / $ram.TotalMB) * 100))%".PadLeft(3) }

    $cpuUsage = if ($cpu -eq "N/A") { "N/A" } else { "$cpu%".PadLeft(3) }

    $ramUsed = if ($ram.UsedMB -eq "N/A") { "N/A" } else { "$($ram.UsedMB) MB".PadLeft(8) }
    $gpuUsed = if ($gpu.UsedMB -eq "N/A") { "N/A" } else { "$($gpu.UsedMB) MB".PadLeft(8) }

    # Linha fixa garantindo espaçamento correto
    $output = "CPU: $cpuUsage  RAM: $ramUsage  GPU: $gpuUsage | RAM-M: $ramUsed  GPU-M: $gpuUsed"

    # Garante que nada extra seja impresso na tela
    [Console]::SetCursorPosition(0, 0)
    Write-Host (" " * 80) -NoNewline  # Apaga a linha anterior
    [Console]::SetCursorPosition(0, 0)
    Write-Host $output -NoNewline

    Start-Sleep -Milliseconds 1
}

# Restaura a janela do Studio se minimizada e a traz para o primeiro plano com foco
# (o Roblox limita o fps de janela sem foco; sem restaurar, a captura sai cinza). Uso: -Foco para forçar o foco.
param([switch]$Foco)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class JanelaStudio {
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
}
"@
$p = Get-Process RobloxStudioBeta | Select-Object -First 1
$h = $p.MainWindowHandle
if ([JanelaStudio]::IsIconic($h)) { [JanelaStudio]::ShowWindow($h, 9) | Out-Null; "restaurada" } else { "ok" }
if ($Foco) {
  [JanelaStudio]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [JanelaStudio]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)  # Alt libera o SetForegroundWindow
  [JanelaStudio]::SetForegroundWindow($h) | Out-Null
  "primeiro plano: " + ([JanelaStudio]::GetForegroundWindow() -eq $h)
}

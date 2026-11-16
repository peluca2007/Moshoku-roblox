# Restaura a janela do Studio se estiver minimizada (sem renderizar, as capturas saem cinza).
Add-Type @"
using System; using System.Runtime.InteropServices;
public class JanelaStudio { [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c); }
"@
$p = Get-Process RobloxStudioBeta | Select-Object -First 1
if ([JanelaStudio]::IsIconic($p.MainWindowHandle)) { [JanelaStudio]::ShowWindow($p.MainWindowHandle, 9) | Out-Null; "restaurada" } else { "ok" }

# Restaura a janela do Roblox Studio se estiver minimizada (a captura de tela do MCP sai em branco).
Add-Type @"
using System; using System.Runtime.InteropServices;
public class JanelaStudio {
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
}
"@
Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object {
  if ([JanelaStudio]::IsIconic($_.MainWindowHandle)) { [JanelaStudio]::ShowWindow($_.MainWindowHandle, 9) | Out-Null; "restaurada $($_.Id)" } else { "visivel $($_.Id)" }
}

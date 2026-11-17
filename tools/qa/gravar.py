"""Grava a janela do Roblox Studio em vídeo (ffmpeg gdigrab) enquanto uma ação roda. Reutilizável.
  from gravar import Gravador
  with Gravador("build/beleza/hab1/corte.mp4", segundos=8): ...ação...
O recorte (crop) pega só o viewport do Studio (sem painéis); ajuste se o layout mudar.
Também por linha de comando (grava N s): python tools/qa/gravar.py saida.mp4 [segundos]
Restaura a janela (studio_janela.ps1) antes; a captura é da tela, então a janela tem de estar visível e sem outra por cima."""
import os, subprocess, sys, time
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TITULO = "MoshokuRPGMesa - Roblox Studio"


def janela():
    subprocess.run(["powershell", "-File", os.path.join(RAIZ, "tools", "qa", "studio_janela.ps1")], capture_output=True)


class Gravador:
    def __init__(self, saida, segundos=8, fps=30):
        self.saida, self.segundos, self.fps, self.p = saida, segundos, fps, None

    def __enter__(self):
        janela()
        os.makedirs(os.path.dirname(os.path.abspath(self.saida)), exist_ok=True)
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "gdigrab", "-framerate", str(self.fps), "-draw_mouse", "0",
               "-i", "title=" + TITULO, "-t", str(self.segundos), "-vf", "crop=trunc(iw*0.84/2)*2:trunc(ih*0.71/2)*2:0:trunc(ih*0.21/2)*2",
               "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p", self.saida]
        self.p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        time.sleep(0.8)
        return self

    def __exit__(self, *a):
        try:
            self.p.wait(timeout=self.segundos + 15)
        except subprocess.TimeoutExpired:
            self.p.communicate(b"q", timeout=10)


if __name__ == "__main__":
    with Gravador(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 5):
        time.sleep(float(sys.argv[2]) if len(sys.argv) > 2 else 5)

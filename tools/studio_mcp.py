"""Cliente mínimo do servidor MCP do Roblox Studio, para testes automáticos.

Uso:
  python tools/studio_mcp.py schemas [ferramenta...]     # descreve as ferramentas
  python tools/studio_mcp.py run <roteiro.json>          # executa uma lista de chamadas

Roteiro: lista de {"tool": "...", "args": {...}} ou {"sleep": segundos}. Em
args, "code_file" substitui "code" pelo conteúdo do arquivo. O
studio_id é preenchido sozinho com o primeiro Studio conectado. Imprime cada
resultado. Requer o Studio aberto com "Ativar o Studio como servidor MCP".

O jogo não tem mestre por padrão (todos em modo jogador). Os roteiros antigos
esperam o primeiro jogador do Studio como mestre: ao iniciar o Play, este
cliente liga o atributo MoshokuTesteMestre no workspace (Edit) e o remove ao
parar ou fechar. MOSHOKU_TESTE_JOGADOR=1 desliga isso para testar como jogador.
"""
import json
import os
import subprocess
import sys
import threading
import time

LAUNCHER = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "mcp.bat")


class Client:
    def __init__(self):
        self.proc = subprocess.Popen(
            ["cmd.exe", "/c", LAUNCHER],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        self.next_id = 0
        self.responses = {}
        self.cond = threading.Condition()
        threading.Thread(target=self._read, daemon=True).start()
        self.request("initialize", {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "moshoku-testes", "version": "0.1"},
        })
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        self.mestre_ligado = None

    def _read(self):
        for raw in self.proc.stdout:
            try:
                message = json.loads(raw.decode("utf-8", errors="replace"))
            except ValueError:
                continue
            if "id" in message:
                with self.cond:
                    self.responses[message["id"]] = message
                    self.cond.notify_all()

    def _send(self, message):
        self.proc.stdin.write((json.dumps(message) + "\n").encode("utf-8"))
        self.proc.stdin.flush()

    def request(self, method, params, timeout=180):
        self.next_id += 1
        ident = self.next_id
        self._send({"jsonrpc": "2.0", "id": ident, "method": method, "params": params})
        deadline = time.time() + timeout
        with self.cond:
            while ident not in self.responses:
                remaining = deadline - time.time()
                if remaining <= 0:
                    raise TimeoutError(method)
                self.cond.wait(remaining)
            return self.responses.pop(ident)

    def _mestre_de_teste(self, studio, ligar):
        valor = "true" if ligar else "nil"
        self._call("execute_luau", {"studio_id": studio, "datamodel_type": "Edit",
                   "code": 'workspace:SetAttribute("MoshokuTesteMestre", %s)' % valor}, 60)
        self.mestre_ligado = studio if ligar else None

    def call(self, tool, args, timeout=180):
        if tool == "start_stop_play" and os.environ.get("MOSHOKU_TESTE_JOGADOR") != "1":
            studio = args.get("studio_id") or self.studio_id()
            if args.get("is_start"):
                self._mestre_de_teste(studio, True)
            result = self._call(tool, args, timeout)
            if not args.get("is_start"):
                self._mestre_de_teste(studio, False)
            return result
        return self._call(tool, args, timeout)

    def _call(self, tool, args, timeout=180):
        response = self.request("tools/call", {"name": tool, "arguments": args}, timeout)
        if "error" in response:
            return {"erro": response["error"]}
        result = response["result"]
        texts = []
        for content in result.get("content", []):
            if content.get("type") == "image" and content.get("data"):
                # Imagens vão para arquivo, para serem abertas depois.
                import base64
                ext = "png" if "png" in content.get("mimeType", "png") else "jpg"
                path = os.path.join(os.environ.get("TEMP", "."), "studio-captura-%d.%s" % (int(time.time() * 1000), ext))
                with open(path, "wb") as handle:
                    handle.write(base64.b64decode(content["data"]))
                texts.append("[imagem salva em " + path + "]")
            else:
                texts.append(content.get("text", "[" + content.get("type", "?") + "]"))
        return {"isError": result.get("isError", False), "text": "\n".join(texts)}

    def studio_id(self, wait=20):
        deadline = time.time() + wait
        while time.time() < deadline:
            data = json.loads(self._call("list_roblox_studios", {})["text"])
            # Prefere a instância com um place aberto (pode haver mais de um Studio conectado).
            for studio in data.get("studios", []):
                estado = self._call("get_studio_state", {"studio_id": studio["id"]})
                if not estado.get("isError") and "Place is not open" not in estado.get("text", ""):
                    return studio["id"]
            time.sleep(1)
        raise SystemExit("Nenhum Studio conectado ao MCP.")

    def close(self):
        if self.mestre_ligado:
            try:
                self._mestre_de_teste(self.mestre_ligado, False)
            except Exception:
                pass
        try:
            self.proc.stdin.close()
            self.proc.terminate()
        except OSError:
            pass


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    client = Client()
    try:
        if sys.argv[1] == "schemas":
            time.sleep(5)  # o proxy anuncia as ferramentas depois de achar o Studio
            tools = client.request("tools/list", {})["result"]["tools"]
            wanted = set(sys.argv[2:])
            for tool in tools:
                if not wanted or tool["name"] in wanted:
                    print("##", tool["name"])
                    print(tool.get("description", "")[:600])
                    print(json.dumps(tool.get("inputSchema", {}), ensure_ascii=False)[:1500])
        elif sys.argv[1] == "run":
            steps = json.load(open(sys.argv[2], encoding="utf-8"))
            studio = client.studio_id()
            for step in steps:
                if "sleep" in step:
                    time.sleep(step["sleep"])
                    continue
                args = dict(step.get("args", {}))
                if "code_file" in args:  # código Luau lido de arquivo, sem escapes de JSON
                    args["code"] = open(args.pop("code_file"), encoding="utf-8").read()
                args.setdefault("studio_id", studio)
                result = client.call(step["tool"], args, step.get("timeout", 180))
                print("##", step["tool"], json.dumps(step.get("args", {}), ensure_ascii=False)[:120])
                print(result.get("text", result)[: step.get("max", 4000)])
    finally:
        client.close()


if __name__ == "__main__":
    main()

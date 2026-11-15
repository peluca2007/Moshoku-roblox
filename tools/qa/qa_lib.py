"""Biblioteca mínima da suíte de QA (cliente MCP com retry, cliques, capturas, console, verificações)."""
import datetime
import json
import os
import re
import shutil
import sys
import time
import unicodedata

os.environ.setdefault("MOSHOKU_TESTE_JOGADOR", "1")
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "tools"))
sys.stdout.reconfigure(encoding="utf-8")
from studio_mcp import Client  # noqa: E402

PASTA_FOTOS = os.path.join(RAIZ, "build", "qa", datetime.date.today().isoformat())
CAMADA_CLIENTE = "LocalPlayer.PlayerGui."


class QaTimeout(Exception):
    pass


class Qa:
    def __init__(self):
        self.c = Client()
        self.sid = self.c.studio_id()
        self.cenario = "-"
        self.ok = 0
        self.falhas = 0
        self.linhas_console = 0
        self.ultima_foto = ""
        self.play = False

    # ---- chamadas MCP ----
    def chamar(self, ferramenta, args, timeout=70, tentativas=3):
        ultimo = None
        for _ in range(tentativas):
            try:
                r = self.c.call(ferramenta, dict(studio_id=self.sid, **args), timeout)
                return r.get("text", str(r)) if isinstance(r, dict) else str(r)
            except TimeoutError as e:
                ultimo = e
        raise QaTimeout("%s sem resposta [%s]" % (ferramenta, re.sub(r"\s+", " ", str(args.get("code") or args.get("actions") or ""))[:70])) from ultimo

    def lua(self, codigo, onde="Client", timeout=70, tentativas=3):
        return self.chamar("execute_luau", dict(datamodel_type=onde, code=codigo), timeout, tentativas).strip()

    def lua_cliente(self, codigo, timeout=70, tentativas=3):
        return self.lua(codigo, "Client", timeout, tentativas)

    def lua_servidor(self, codigo, timeout=70, tentativas=3):
        return self.lua(codigo, "Server", timeout, tentativas)

    def clique(self, caminho, espera=800):
        """Clique real por caminho (ex. 'LocalPlayer.PlayerGui.X.Y')."""
        return self.chamar("user_mouse_input", dict(datamodel_type="Client", actions=[
            {"action": "moveTo", "instance_path": caminho}, {"action": "wait", "wait_time_ms": 150},
            {"action": "mouseButtonClick", "mouse_button": "left"},
            {"action": "wait", "wait_time_ms": espera}]))

    def tecla(self, tecla, segurar_ms=150, depois_ms=800):
        return self.chamar("user_keyboard_input", dict(datamodel_type="Client", actions=[
            {"action": "keyDown", "key_code": tecla}, {"action": "wait", "wait_time_ms": segurar_ms},
            {"action": "keyUp", "key_code": tecla}, {"action": "wait", "wait_time_ms": depois_ms}]))

    def achar(self, nome, raiz="", classe="GuiObject", visivel=True):
        """Caminho (LocalPlayer....) da primeira Instance com esse nome sob PlayerGui[.raiz] (por padrão só as visíveis), ou ''."""
        base = "game.Players.LocalPlayer.PlayerGui" + ("." + raiz if raiz else "")
        return self.lua_cliente("local pg=game.Players.LocalPlayer.PlayerGui local b=%s local function vis(d) local x=d while x and x~=pg do "
                                "if (x:IsA('GuiObject') and not x.Visible) or (x:IsA('ScreenGui') and not x.Enabled) then return false end x=x.Parent end return true end "
                                "for _,d in b:GetDescendants() do if d.Name==%s and d:IsA(%s) and (%s or vis(d)) then "
                                "return (d:GetFullName():gsub('^Players%%.[^.]+%%.','LocalPlayer.')) end end return ''"
                                % (base, json.dumps(nome), json.dumps(classe), "false" if visivel else "true"))

    def clicar_nome(self, nome, raiz="", espera=800):
        p = self.achar(nome, raiz, "GuiButton")
        if not p:
            return False
        self.clique(p, espera)
        return True

    def esperar(self, condicao, timeout=15, passo=1.0):
        """condicao: callable -> truthy. Devolve o último valor."""
        fim = time.time() + timeout
        v = None
        while True:
            try:
                v = condicao()
            except QaTimeout:
                v = None
            if v:
                return v
            if time.time() >= fim:
                return v
            time.sleep(passo)

    def esperar_lua(self, expr, timeout=15, onde="Client"):
        """Espera uma expressão Luau (devolve true/valor) ficar truthy; devolve o texto final."""
        def f():
            r = self.lua("return tostring(%s)" % expr, onde)
            return r if r not in ("", "false", "nil") else None
        return self.esperar(f, timeout)

    def play_ligar(self):
        self.chamar("start_stop_play", {"is_start": True}, 150, 2)
        self.play = True

    def play_parar(self):
        try:
            self.chamar("start_stop_play", {"is_start": False}, 150, 2)
        finally:
            self.play = False

    # ---- capturas e console ----
    def foto(self, nome, estavel=None):
        """Captura. `estavel`: nome fixo extra (build/qa/<data>/<estavel>.png) para a página de apresentação."""
        try:
            t = self.chamar("screen_capture", {"capture_id": nome}, 60, 2)
        except QaTimeout:
            return "(captura sem resposta)"
        m = re.search(r"\[imagem salva em (.+?)\]", t)
        if not m:
            return "(sem imagem)"
        os.makedirs(PASTA_FOTOS, exist_ok=True)
        destino = os.path.join(PASTA_FOTOS, "%s_%s.png" % (self.cenario, nome))
        shutil.copyfile(m.group(1), destino)
        if estavel:
            shutil.copyfile(m.group(1), os.path.join(PASTA_FOTOS, estavel + ".png"))
        self.ultima_foto = os.path.relpath(destino, RAIZ).replace("\\", "/")
        return self.ultima_foto

    RUIDO = re.compile(r"changed camera type|Resetting|Studio MCP|\[QA\]|HttpService|Avatar|DataStore|StudioMode|"
                       r"AssistantCommand|ExecuteLuauTool|Stack (Begin|End)|Failed to load sound|rbxassetid.*(403|404)|Roblox Studio|Rojo|MemoryStore", re.I)
    ERRO = re.compile(r"error|erro|attempt to|invalid|stack begin|nil value|falha|failed|warning|not a valid member|"
                      r"infinite yield|exception", re.I)

    def console_erros(self, maximo=5):
        """Linhas de erro/aviso novas desde a última leitura (já deduplicadas), no máximo `maximo`."""
        try:
            t = self.chamar("get_console_output", {}, 60, 2)
        except QaTimeout:
            return []
        linhas = t.splitlines()
        if len(linhas) < self.linhas_console:
            self.linhas_console = 0
        novas, self.linhas_console = linhas[self.linhas_console:], len(linhas)
        vistos, saida = set(), []
        for l in novas:
            if self.ERRO.search(l) and not self.RUIDO.search(l):
                k = re.sub(r"\d+", "#", l)[:160]
                if k not in vistos:
                    vistos.add(k)
                    saida.append(l.strip()[:200])
        return saida[:maximo]

    # ---- relatório ----
    def verificar(self, nome, condicao, detalhe="", foto=False):
        if condicao:
            self.ok += 1
            print("OK   %s · %s" % (self.cenario, nome), flush=True)
        else:
            self.falhas += 1
            f = self.foto("falha_" + re.sub(r"\W+", "_", nome)[:30]) if foto else self.ultima_foto
            extra = (" — " + str(detalhe)[:160]) if detalhe else ""
            print("FALHA %s · %s%s%s" % (self.cenario, nome, extra, (" [" + f + "]") if f else ""), flush=True)
        return bool(condicao)

    def erros_do_console(self):
        for l in self.console_erros():
            print("  console> " + l, flush=True)

    def fechar(self):
        try:
            if self.play:
                self.play_parar()
        except Exception:
            pass
        self.c.close()


LUA_TELA = r"""
local pg=game.Players.LocalPlayer.PlayerGui
local function cut(s,n) local e=utf8.offset(s,n+1) return e and s:sub(1,e-1) or s end
local function vis(d) local x=d local n=0 while x and x~=pg and n<60 do n+=1
  if (x:IsA('GuiObject') and not x.Visible) or (x:IsA('ScreenGui') and not x.Enabled) then return false end x=x.Parent end return true end
local out={}
for _,g in pg:GetChildren() do if g:IsA('ScreenGui') and g.Enabled then
  local t={}
  for _,d in g:GetDescendants() do
    if (d:IsA('TextLabel') or d:IsA('TextButton')) and d.Text~='' and vis(d) then table.insert(t,cut(d.Text,@C@)) end
  end
  if #t>0 then table.insert(out,g.Name..': '..cut(table.concat(t,' | '),@T@)) end
end end
return table.concat(out,' ;; ')
"""


def norm(t):
    """Sem acentos, sem espaçamento de letras: minúsculas, só [a-z0-9 ]. Para comparar textos da interface."""
    t = unicodedata.normalize("NFKD", t or "")
    return re.sub(r"[^a-z0-9 ]", "", t.lower())


def tela(q, curto=40, total=400):
    """Texto visível por ScreenGui, normalizado (ver norm)."""
    return norm(q.lua_cliente(LUA_TELA.replace('@C@', str(curto)).replace('@T@', str(total))).replace(";;", "  ;;  ").replace("|", " "))


def tela_de(q, gui, total=500):
    """Texto visível (normalizado, SEM espaços) de um ScreenGui; '' se não existir/oculto."""
    r = q.lua_cliente(LUA_TELA.replace('@C@', "60").replace('@T@', str(total * 3)))
    for bloco in r.split(" ;; "):
        if bloco.startswith(gui + ":"):
            return norm(bloco[len(gui) + 1:]).replace(" ", "")
    return ""


LUA_VISAO = r"""
local H=game:GetService('HttpService') local rj=game.ReplicatedStorage.RunJogo local got
local con=rj.OnClientEvent:Connect(function(t,d) if t=='run' then got=d end end)
rj:FireServer({acao='consultar'}) local t=os.clock() while not got and os.clock()-t<6 do task.wait(0.1) end con:Disconnect()
if not got then return '{"semResposta":true}' end
local o={} for k,v in got do if type(v)~='table' then o[k]=v end end
o.nOpcoes=type(got.opcoes)=='table' and #got.opcoes or 0
if type(got.opcoes)=='table' then local ids={} for _,x in got.opcoes do table.insert(ids,tostring(type(x)=='table' and (x.id or x.titulo) or x)) end o.ids=ids end
return H:JSONEncode(o)
"""


def visao(q):
    """Estado da run visto pelo cliente (evento 'run' do RunJogo) como dict."""
    try:
        return json.loads(q.lua_cliente(LUA_VISAO))
    except (ValueError, QaTimeout):
        return {"semResposta": True}


def teleportar(q, x, y, z):
    return q.lua_servidor("local p=game.Players:GetPlayers()[1] p.Character:PivotTo(CFrame.new(%s,%s,%s)) task.wait(0.6) "
                          "return tostring(p.Character.HumanoidRootPart.Position)" % (x, y, z))


def aproximar_do_alvo(q, alvo, dist=4.0):
    """Leva o avatar para `dist` studs diante de `alvo` (x,y,z) segundo a direção da câmera atual, para o
    ProximityPrompt do alvo ficar dentro da tela (o prompt só aparece com o alvo no campo de visão)."""
    r = q.lua_cliente("local l=workspace.CurrentCamera.CFrame.LookVector local v=Vector3.new(l.X,0,l.Z).Unit "
                      "return v.X..','..v.Z")
    try:
        lx, lz = [float(t) for t in r.split(",")]
    except ValueError:
        lx, lz = 0.0, -1.0
    teleportar(q, round(alvo[0] - lx * dist, 2), alvo[1], round(alvo[2] - lz * dist, 2))
    time.sleep(1.5)


def segurar_e(q, ms=1600, depois=1200):
    return q.tecla("E", ms, depois)


def lua_arquivo(q, caminho_rel, onde="Client", troca=None, timeout=70, tentativas=3):
    """Executa um .luau do repositório (ex. tools/playtest/mundo_bot_combate2.luau), com trocas de texto opcionais."""
    codigo = open(os.path.join(RAIZ, caminho_rel), encoding="utf-8").read()
    for a, b in (troca or {}).items():
        codigo = codigo.replace(a, b)
    return q.lua(codigo, onde, timeout, tentativas)

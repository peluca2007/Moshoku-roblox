"""Passos do fluxo do jogo reutilizados pelos cenários (criação, Ladino, porta do esgoto, luta, acampamento)."""
import re

from qa_lib import *  # noqa: F401,F403

CRIACAO = "LocalPlayer.PlayerGui.CriacaoRapida.Fundo.Moldura.Conteudo."
GUI_EXP = "ExpedicaoJogo"
PORTA = (-4, 3, -186)

LUA_FAIXA = r"""
local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ExpedicaoJogo') if not g then return '' end
local f=g:FindFirstChild('Faixa') if not f or not f.Visible then return '' end
local t={} for _,d in f:GetDescendants() do if d:IsA('TextLabel') and d.Text~='' then table.insert(t,d.Text) end end
return table.concat(t,' ')
"""


def faixa(q):
    """Texto normalizado da faixa da expedição (ex. 'dia 2 sala 1 5 ...')."""
    return norm(q.lua_cliente(LUA_FAIXA))


def dia_da_faixa(q):
    m = re.search(r"dia (\d+)", faixa(q))
    return int(m.group(1)) if m else None


def combate(q):
    return q.lua_cliente("return tostring(game.Players.LocalPlayer:GetAttribute('InterfaceCombate'))") == "true"


def ancorado(q):
    return q.lua_servidor("local c=game.Players:GetPlayers()[1].Character return tostring(c.HumanoidRootPart.Anchored)") == "true"


def objetivo(q):
    """Texto normalizado do cartão de objetivo (OrientacaoJogador)."""
    return tela_de(q, "OrientacaoJogador")


def criar_personagem(q):
    """Play -> abertura -> criação (3 avanços). Devolve (modelos_na_previa, raca_selecionada_ok)."""
    q.play_ligar()
    q.esperar_lua("game.Players.LocalPlayer.PlayerGui:FindFirstChild('CenaAbertura') and "
                  "game.Players.LocalPlayer.PlayerGui.CenaAbertura:FindFirstChild('Pular')", 60)
    time.sleep(4)
    q.foto("abertura", "abertura")
    q.clique("LocalPlayer.PlayerGui.CenaAbertura.Pular", 500)
    q.esperar_lua("game.Players.LocalPlayer.PlayerGui:FindFirstChild('CriacaoRapida') and "
                  "game.Players.LocalPlayer.PlayerGui.CriacaoRapida.Fundo.Moldura.Conteudo.Area.Raca.Racas:FindFirstChild('Raca_humano')", 30)
    time.sleep(1.5)


PREVIA = ("local n=0 local v=game.Players.LocalPlayer.PlayerGui.CriacaoRapida.Fundo.Moldura.Conteudo.Previa.Previa3D "
          "for _,x in v:GetDescendants() do if x:IsA('Model') then n+=1 end end return tostring(n)")


def avancar_criacao(q):
    q.clique(CRIACAO + "Rodape.Avancar")


def ladino(q):
    """Atalho do Ladino: aprende a primeira árvore (diálogo, provação do sino, arma). Devolve notas."""
    notas = []
    teleportar(q, 65, 3, -222)
    for _ in range(4):
        segurar_e(q, 1500, 1200)
        r = q.lua_cliente("""local c=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ConversaNpc') local d=c and c:FindFirstChild('DialogoNpc')
if not d then return 'sem' end
for _,b in d.Conteudo:GetChildren() do if b.Name=='Botao' then local r=b:FindFirstChild('Rotulo') b.Name='B_'..((r and r.Text or '?'):gsub('[^%w]','')) end end return 'ok'""")
        if r == "ok":
            break
    notas.append("dialogo=" + r)
    q.clique("LocalPlayer.PlayerGui.ConversaNpc.DialogoNpc.Conteudo.B_Treinar", 1500)
    q.lua_cliente("""local r=game.ReplicatedStorage:FindFirstChild('TreinadorJogo') local H=game:GetService('HttpService')
local npc for _,m in workspace.Vila.TreinadoresRun:GetChildren() do if m.Name=='Ladino' then npc=m end end
r:FireServer({acao='aceitar',npcId=npc:GetAttribute('TreinadorId'),requestId=H:GenerateGUID(false)}) task.wait(1.5) return 'aceita'""")
    src = open(os.path.join(RAIZ, "tools", "playtest", "mundo_ladino_atalho.py"), encoding="utf-8").read()
    caixas = re.search(r'CAIXAS = """(.*?)"""', src, re.S).group(1)
    for tentativa in range(3):
        q.lua_servidor(caixas)
        teleportar(q, 64, 3, -263)
        q.lua_cliente("""local s=workspace.ProvacoesTreinadores["Pátio do Ladino"].Sino.ProximityPrompt
s:InputHoldBegin() task.wait(1.7) s:InputHoldEnd() task.wait(0.6) return 'sino'""")
        teleportar(q, 65, 3, -231.5)
        q.lua_cliente("""local root=game.Players.LocalPlayer.Character.HumanoidRootPart
for _,d in workspace:GetDescendants() do if d:IsA('ProximityPrompt') and d.Parent.Name~='Portão' and d.Parent:IsA('BasePart') and (d.Parent.Position-root.Position).Magnitude<14 then d.Enabled=false end end task.wait(1.5) return 'ok'""")
        q.tecla("E", 900, 2500)
        q.lua_cliente("for _,d in workspace:GetDescendants() do if d:IsA('ProximityPrompt') then d.Enabled=true end end return 'ok'")
        q.lua_servidor("local f=workspace:FindFirstChild('AnteparosTesteLadino') if f then f:Destroy() end return 'ok'")
        if "aprovado" in tela_de(q, "ProvacaoEstado") or "aprovado" in tela(q).replace(" ", ""):
            notas.append("provacao ok (tentativa %d)" % (tentativa + 1))
            break
        notas.append("provacao falhou (tentativa %d)" % (tentativa + 1))
        time.sleep(3)
    q.lua_cliente("""game.ReplicatedStorage.Mesa:FireServer('personagemPessoalEquiparArma',{sourceLocalId='kit-inicial-01',requestId='arma-'..tostring(os.clock())}) task.wait(2) return 'arma enviada'""")
    return notas


def ir_para_porta(q):
    teleportar(q, *PORTA)
    time.sleep(1)


def abrir_painel_porta(q):
    ir_para_porta(q)
    segurar_e(q, 1700, 1500)
    return q.achar("Escolher_entrar-esgoto", GUI_EXP, "GuiButton")


def entrar_no_esgoto(q):
    """Abre o painel da porta e escolhe 'entrar-esgoto'. Devolve True se o botão existia."""
    p = abrir_painel_porta(q)
    if not p:
        return False
    q.clique(p, 3000)
    return True


def lutar(q, max_chamadas=6):
    """Joga a luta com tools/qa/bot_luta.luau até acabar. Devolve 'fase=...' (vitoria/derrota/ativa/encerrada)."""
    ult = ""
    for _ in range(max_chamadas):
        ult = lua_arquivo(q, "tools/qa/bot_luta.luau", troca={"@TEMPO@": "40"}, timeout=100, tentativas=1)
        if re.search(r"fase=(vitoria|derrota|encerrada|erro)", ult):
            break
    return ult.splitlines()[0][:200] if ult else ""


def acao_luta(q, modo, max_chamadas=10):
    """Faz um golpe/disparo (sem esperar a animação) e devolve 'golpe'/'disparo'/outro. A captura sai logo depois."""
    for _ in range(max_chamadas):
        r = lua_arquivo(q, "tools/qa/acao_luta.luau", troca={"@MODO@": modo}, timeout=60, tentativas=1)
        if r in ("golpe", "disparo", "fim", "semalvo") or r.startswith("erro"):
            return r
    return "sem"


def clicar_visivel(q, gui, espera=1000):
    """Clica o primeiro GuiButton visível do ScreenGui (ex. 'Continuar' do resultado). Devolve o caminho ou ''."""
    p = q.lua_cliente("""local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('%s') if not g then return '' end
local function vis(d) local x=d while x and x~=g do if x:IsA('GuiObject') and not x.Visible then return false end x=x.Parent end return true end
for _,d in g:GetDescendants() do if d:IsA('GuiButton') and vis(d) then return (d:GetFullName():gsub('^Players%%.[^.]+%%.','LocalPlayer.')) end end return ''""" % gui)
    if p.startswith("LocalPlayer"):
        q.clique(p, espera)
    return p


def clicar_texto(q, gui, trecho, espera=1000):
    """Clica o botão visível de `gui` cujo texto (dele ou de um filho) contém `trecho` (sem diferenciar maiúsculas).
    Renomeia o botão achado (os da lista têm todos o nome 'Botao') e devolve o caminho, ou '' se não achou."""
    p = q.lua_cliente("""local pg=game.Players.LocalPlayer.PlayerGui local g=pg:FindFirstChild(%s) if not g then return '' end
local function vis(d) local x=d while x and x~=pg do if (x:IsA('GuiObject') and not x.Visible) or (x:IsA('ScreenGui') and not x.Enabled) then return false end x=x.Parent end return true end
local alvo=(%s):lower()
for _,b in g:GetDescendants() do if b:IsA('GuiButton') and vis(b) then
  local t=(b:IsA('TextButton') and b.Text or '')
  for _,x in b:GetDescendants() do if x:IsA('TextLabel') then t=t..' '..x.Text end end
  if t:lower():find(alvo,1,true) then b.Name='QA_'..tostring(math.random(1,999999))
    local f=b.Parent while f and f~=g do if f:IsA('ScrollingFrame') then -- rola para o botão ficar visível (como o jogador faria)
      local dx=b.AbsolutePosition.X-f.AbsolutePosition.X-(f.AbsoluteSize.X-b.AbsoluteSize.X)/2
      local dy=b.AbsolutePosition.Y-f.AbsolutePosition.Y-(f.AbsoluteSize.Y-b.AbsoluteSize.Y)/2
      f.CanvasPosition=Vector2.new(math.max(0,f.CanvasPosition.X+(f.ScrollingDirection~=Enum.ScrollingDirection.Y and dx or 0)),math.max(0,f.CanvasPosition.Y+(f.ScrollingDirection~=Enum.ScrollingDirection.X and dy or 0))) task.wait(0.2) end f=f.Parent end
    return (b:GetFullName():gsub('^Players%%.[^.]+%%.','LocalPlayer.')) end
end end return ''""" % (json.dumps(gui), json.dumps(trecho)))
    if p.startswith("LocalPlayer"):
        q.clique(p, espera)
    return p


def clicar_na_lista(q, gui, indice, espera=1000):
    """Clica o N-ésimo botão visível do contêiner `Lista` de `gui` (1 = primeiro). Devolve o texto dele ('' se não houver)."""
    r = q.lua_cliente("""local pg=game.Players.LocalPlayer.PlayerGui local g=pg:FindFirstChild(%s) local l=g and g:FindFirstChild('Lista',true) if not l then return '' end
local n=0 for _,b in l:GetDescendants() do if b:IsA('GuiButton') and b.Visible then n+=1 if n==%d then
  local t=(b:IsA('TextButton') and b.Text or '') for _,x in b:GetDescendants() do if x:IsA('TextLabel') then t=t..' '..x.Text end end
  b.Name='QA_'..tostring(math.random(1,999999))
  local f=b.Parent while f and f~=g do if f:IsA('ScrollingFrame') then f.CanvasPosition=Vector2.new(0,math.max(0,f.CanvasPosition.Y+b.AbsolutePosition.Y-f.AbsolutePosition.Y-20)) task.wait(0.2) end f=f.Parent end
  return (b:GetFullName():gsub('^Players%%.[^.]+%%.','LocalPlayer.'))..'|'..t end end end return ''""" % (json.dumps(gui), indice))
    if "|" not in r:
        return ""
    p, t = r.split("|", 1)
    q.clique(p, espera)
    return t.strip()


def vitrine(q):
    """(modelos/partes na Vitrine, nome do primeiro filho) segundo o servidor."""
    return q.lua_servidor("local v=workspace.AreaDeTestes:FindFirstChild('Vitrine') if not v then return '0|' end local c=v:GetChildren()[1] return #v:GetDescendants()..'|'..(c and c.Name or '')")


def som_tocando(q):
    return q.lua_cliente("for _,s in game:GetService('SoundService'):GetDescendants() do if s:IsA('Sound') and s.IsPlaying then return s.Name end end for _,s in workspace:GetDescendants() do if s:IsA('Sound') and s.IsPlaying and s.Name=='TesteSom' then return s.Name end end return ''")

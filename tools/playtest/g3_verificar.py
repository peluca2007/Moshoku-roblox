"""Qualidade de vida das cartas, com cliques reais e treino local."""
import json
from pathlib import Path
import re
import shutil
import sys
import time
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client
import studio_sync

base = Path(__file__).parent
c = Client()
sid, iniciou = None, False

def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args))
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r["text"]

def lua(code):
    return call("execute_luau", datamodel_type="Client", code=code)

def press(path):
    pos = json.loads(lua('local o='+path+'; local a=o.Parent; while a and not a:IsA("ScrollingFrame") do a=a.Parent end; if a then local y=o.AbsolutePosition.Y-a.AbsolutePosition.Y; if y<0 then a.CanvasPosition+=Vector2.new(0,y) elseif y+o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y+o.AbsoluteSize.Y-a.AbsoluteSize.Y) end end; task.wait(.15); local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({p.X,p.Y})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(.25)

def capture(name):
    cap = call("screen_capture", capture_id=name)
    match = re.search(r"\[imagem salva em (.*?)\]", cap)
    if match:
        shutil.copyfile(match[1], base / (name + Path(match[1]).suffix))

def check(code):
    print(lua('local r=shared.G3; local g=r.gui; local b=g.Barra; '+code), flush=True)

try:
    studios = json.loads(c.call("list_roblox_studios", {})["text"])["studios"]
    local = [s for s in studios if s["name"] == "Moshoku-Prototipo.rbxlx"]
    assert len(local) == 1, studios
    sid = local[0]["id"]
    assert "- Current Studio Mode: Edit" in call("get_studio_state").splitlines()
    items = studio_sync.collect()
    for start in range(0, len(items), 6):
        result = call("execute_luau", datamodel_type="Edit", code=studio_sync.chunk_code(items[start:start+6]))
        assert result.startswith("alterados:"), result
    print("Fontes sincronizadas", flush=True)
    print(call("start_stop_play", is_start=True), flush=True); iniciou = True
    time.sleep(8)
    print(call("execute_luau", datamodel_type="Server", code='local r=game.ServerScriptService.Server; local p,f=require(r.TestRunner).run(r.tests); assert(f==0); return p.." specs aprovados"'), flush=True)
    print(lua((base / "g3_cliente.luau").read_text(encoding="utf-8")), flush=True)
    root = 'game.Players.LocalPlayer.PlayerGui.G3BarraTeste'
    bar = root+'.Barra'
    press(bar+'.Cartas["Carta_mesa/ataque-basico"].Detalhes')
    check('r.check("interrogacao abre consulta",g.DetalheAcao.Visible); r.check("consultar nao arma nem envia",r.state.mira()==nil and r.disparos==0 and r.pedidos==0); r.check("descricao completa disponivel",#g.DetalheAcao.Painel.Texto.Conteudo.Text>30); r.check("custo da acao explicito",string.find(g.DetalheAcao.Painel.Custo.Text,"AÇÃO",1,true)~=nil); return "consulta"')
    press(root+'.DetalheAcao.Painel.Custo')
    check('r.check("tocar no conteudo nao fecha consulta",g.DetalheAcao.Visible); return "conteudo"')
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=8, y=200),
        dict(action="mouseButtonUp", mouse_button="left", x=8, y=200)])
    check('r.check("toque fora fecha consulta",not g.DetalheAcao.Visible); return "fora"')
    press(bar+'.Cartas["Carta_mesa/ataque-basico"].Detalhes')
    press(root+'.DetalheAcao.Painel.Voltar')
    check('r.check("voltar fecha consulta",not g.DetalheAcao.Visible); return "fechou"')
    press(bar+'.Grupos.Apoio')
    press(bar+'.Cartas["Carta_mesa/dissonancia"]')
    check('r.check("self tem confirmacao explicita",b.Controles.ConfirmarAcao.Visible and b.Controles.ConfirmarAcao.Text=="Usar habilidade"); r.check("preparar nao executa",r.disparos==0); return "self"')
    capture("g3_confirmar")
    press(bar+'.Controles.ConfirmarAcao')
    check('r.check("confirmacao executa uma vez",r.disparos==1 and r.ultimaMira.habilidadeId=="mesa/dissonancia"); r.check("confirmar limpa mira",r.state.mira()==nil and not b.Controles.ConfirmarAcao.Visible); return "confirmou"')
    press(bar+'.Cartas["Carta_lanca-de-pedra"]')
    check('r.check("lista sem alvos pede selecao",b.Controles.ConfirmarAcao.Visible and b.Controles.ConfirmarAcao:GetAttribute("Bloqueada")); return "lista"')
    press(bar+'.Controles.ConfirmarAcao')
    check('r.check("lista vazia nao executa",r.disparos==1); local m=r.state.mira(); m.alvoIds={"alvoA","alvoB"}; r.state.setMira(m); r.check("contagem explicita dos alvos",b.Controles.ConfirmarAcao.Text=="Confirmar 2 alvos" and not b.Controles.ConfirmarAcao:GetAttribute("Bloqueada")); return "alvos"')
    press(bar+'.Controles.ConfirmarAcao')
    check('r.check("lista confirmada conserva alvos",r.disparos==2 and #r.ultimaMira.alvoIds==2); return "lista confirmada"')
    press(bar+'.Cartas["Carta_mesa/dissonancia"]')
    check('r.snap.jogo.acoes.usadas=3; r.atualizar(); r.check("confirmacao acompanha recurso gasto",b.Controles.ConfirmarAcao:GetAttribute("Bloqueada")); return "sem acoes"')
    press(bar+'.Controles.ConfirmarAcao')
    check('r.check("confirmacao nao contorna bloqueio local",r.disparos==2); return "bloqueio"')
    press(bar+'.Cartas["Carta_mesa/dissonancia"]')
    check('r.check("carta bloqueada abre explicacao",g.DetalheAcao.Visible and g.DetalheAcao.Painel.Situacao.Text=="Sem Ações"); r.check("bloqueio conserva descricao",#g.DetalheAcao.Painel.Texto.Conteudo.Text>20); r.snap.jogo.acoes.usadas=0; r.atualizar(); r.check("consulta acompanha disponibilidade",g.DetalheAcao.Painel.Situacao.Text~="Sem Ações"); r.snap.combat.turn+=1; r.atualizar(); r.check("novo turno fecha consulta e cancela mira",not g.DetalheAcao.Visible and r.state.mira()==nil); return "consulta viva"')
    press(bar+'.Cartas["Carta_mesa/dissonancia"]')
    check('r.check("mira armada antes da troca",r.state.mira()~=nil); r.snap.combat.turn+=1; r.atualizar(); r.check("troca de turno descarta mira armada",r.state.mira()==nil and not b.Controles.ConfirmarAcao.Visible); return "mira antiga"')
    press(bar+'.Grupos.Tudo')
    press(bar+'.Cartas["Carta_sem-recuo"]')
    check('r.check("passiva pode ser lida",g.DetalheAcao.Visible and string.find(g.DetalheAcao.Painel.Texto.Conteudo.Text,"Passiva",1,true)~=nil); r.check("consulta nao inventa custo zero",g.DetalheAcao.Painel.Custo.Text=="CONSULTA"); g.DetalheAcao.Painel.UISizeConstraint.MaxSize=Vector2.new(375,500); task.wait(.3); r.check("consulta cabe em 375 px",g.DetalheAcao.Painel.AbsoluteSize.X<=375); for _,o in g.DetalheAcao.Painel:GetChildren() do if o:IsA("TextButton") then r.check(o.Name.." tem 44 px",o.AbsoluteSize.Y>=44) end end; return "passiva compacta"')
    capture("g3_detalhe_375")
    press(root+'.DetalheAcao.Painel.Fechar')
    check('r.check("fechar pelo X funciona",not g.DetalheAcao.Visible); b.Cartas.CanvasPosition=Vector2.new(0,80); task.wait(.2); r.check("lista permite rolagem antes de trocar",b.Cartas.CanvasPosition.Y>0); return "rolagem"')
    press(bar+'.Grupos.Apoio')
    check('r.check("trocar grupo volta ao inicio",b.Cartas.CanvasPosition.Y==0); return "aba"')
    press(bar+'.Cartas["Carta_mesa/esconder"].Detalhes')
    check('r.snap.combat.active=false; r.atualizar(); r.check("sair do combate fecha consulta",not g.DetalheAcao.Visible and not b.Visible); g:Destroy(); r.menu.Visible=r.menuAnterior; return "bancada limpa"')
    print(lua('local remote=game.ReplicatedStorage.Mesa; shared.G3con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then shared.G3real=d elseif k=="efeito" then shared.G3efeito=d end end); remote:FireServer("escolherPersonagem",{id="bardo"}); task.wait(.5); remote:FireServer("iniciarTreino",{}); task.wait(2); return "treino real"'), flush=True)
    real = 'game.Players.LocalPlayer.PlayerGui.AcoesDoTurno'
    press(real+'.Barra.Grupos.Apoio')
    press(real+'.Barra.Cartas["Carta_mesa/dissonancia"].Detalhes')
    print(lua('local r=shared.G3; local g=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno; r.check("consulta real nao gasta acao",g.DetalheAcao.Visible and shared.G3real.jogo.acoes.usadas==0 and shared.G3efeito==nil); return "consulta real"'), flush=True)
    press(real+'.DetalheAcao.Painel.Voltar')
    press(real+'.Barra.Cartas["Carta_mesa/dissonancia"]')
    press(real+'.Barra.Controles.ConfirmarAcao')
    print(lua('task.wait(.3); local r=shared.G3; r.check("botao real recebe acao confirmada",shared.G3efeito and shared.G3efeito.habilidadeId=="mesa/dissonancia"); r.check("confirmacao real cobra uma Acao",shared.G3real.jogo.acoes.usadas==1); r.check("botao real some depois de usar",not game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.ConfirmarAcao.Visible); return "acao real"'), flush=True)
    capture("g3_acao_real")
    result = lua('game.ReplicatedStorage.Mesa:FireServer("sairPartida",{}); task.wait(.5); shared.G3con:Disconnect(); local r=shared.G3; return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")')
    print(result, flush=True)
    assert "FINAL 0" in result and "FALHA " not in result, result
    print("Console:", call("get_console_output"), flush=True)
finally:
    if iniciou:
        print(call("start_stop_play", is_start=False), flush=True)
        print(call("get_studio_state"), flush=True)
    c.close()

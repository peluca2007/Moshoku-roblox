"""Reações: leitura, entrada real e perguntar do ReacoesService em canal isolado."""
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

def server(code):
    return call("execute_luau", datamodel_type="Server", code=code)

def check(code):
    print(lua('local r=shared.G4; local g=r.gui; local f=g.Fundo; local b=f.Caixa; '+code), flush=True)

def key(name):
    call("user_keyboard_input", datamodel_type="Client", actions=[dict(action="keyPress", key_code=name)])
    time.sleep(.2)

def press(path):
    pos = json.loads(lua('local o='+path+'; local a=o.Parent; while a and not a:IsA("ScrollingFrame") do a=a.Parent end; if a then local y=o.AbsolutePosition.Y-a.AbsolutePosition.Y; if y<0 or o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y) elseif y+o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y+o.AbsoluteSize.Y-a.AbsoluteSize.Y) end end; task.wait(.2); local p=o.AbsolutePosition+o.AbsoluteSize/2; if a then p=Vector2.new(p.X,(math.max(o.AbsolutePosition.Y,a.AbsolutePosition.Y)+math.min(o.AbsolutePosition.Y+o.AbsoluteSize.Y,a.AbsolutePosition.Y+a.AbsoluteSize.Y))/2) end; return game.HttpService:JSONEncode({p.X,p.Y})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(.2)

def capture(name):
    match = re.search(r"\[imagem salva em (.*?)\]", call("screen_capture", capture_id=name))
    if match:
        shutil.copyfile(match[1], base / (name + Path(match[1]).suffix))

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
    print(server('local r=game.ServerScriptService.Server; local p,f=require(r.TestRunner).run(r.tests); assert(f==0); return p.." specs aprovados"'), flush=True)
    print(server((base / "g4_servidor.luau").read_text(encoding="utf-8")), flush=True)
    print(lua((base / "g4_cliente.luau").read_text(encoding="utf-8")), flush=True)
    root = 'game.Players.LocalPlayer.PlayerGui.G4ReacaoTeste.Fundo.Caixa'
    check('r.mostrar(101,45,4,true); b.UISizeConstraint.MaxSize=Vector2.new(375,380); task.wait(.4); r.check("reacao abre centralizada",f.Visible and math.abs(b.AbsolutePosition.X+b.AbsoluteSize.X/2-g.AbsoluteSize.X/2)<2); r.check("janela compacta limitada",b.AbsoluteSize.X<=375 and b.AbsoluteSize.Y<=380); r.check("deixar passar tem 44 px",b.Passar.AbsoluteSize.Y>=44); r.check("prazo tem segundos",string.find(b.Contagem.Text,"s para escolher",1,true)~=nil); r.check("atalhos cabem",b.Atalhos.TextFits); r.check("detalhes nao truncados",b.Opcoes.Opcao_1.Detalhe.TextTruncate==Enum.TextTruncate.None and b.Opcoes.Opcao_1.Detalhe.AbsoluteSize.Y>18); r.check("opcoes longas tem rolagem",b.Opcoes.AbsoluteCanvasSize.Y>b.Opcoes.AbsoluteSize.Y); for _,o in b.Opcoes:GetChildren() do if o:IsA("TextButton") then r.check(o.Name.." tem toque >=44",o.AbsoluteSize.Y>=44) end end; return "leitura"')
    capture("g4_reacao_375")
    pos = json.loads(lua('local o=shared.G4.gui.Fundo.Caixa.Opcoes; local p=o.AbsolutePosition; return game.HttpService:JSONEncode({p.X+o.AbsoluteSize.X-2,p.Y+8})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="moveTo", x=round(pos[0]), y=round(pos[1])), dict(action="mouseButtonDown", mouse_button="left"),
        dict(action="moveTo", x=round(pos[0]), y=round(pos[1]+100)), dict(action="wait", wait_time_ms=200),
        dict(action="mouseButtonUp", mouse_button="left")])
    check('r.check("arrasto real rola detalhes",b.Opcoes.CanvasPosition.Y>0); return "rolagem"')
    press(root+'.Opcoes.Opcao_3')
    check('r.check("clique na opcao envia id correto",#r.envios==1 and r.envios[1].dados.escolha=="opcao3"); r.check("responder fecha janela",not f.Visible); return "respondeu"')
    key("Three")
    check('r.check("tecla depois de responder nao duplica",#r.envios==1); r.mostrar(102,45,4,false); return "nova"')
    key("Four")
    check('r.check("atalho 4 funciona",#r.envios==2 and r.envios[2].dados.escolha=="opcao4" and not f.Visible); r.mostrar(103,45,1,false); return "tecla 4"')
    press(root+'.Passar')
    check('r.check("passar explicito envia nil",#r.envios==3 and r.envios[3].dados.escolha==nil and not f.Visible); r.mostrar(104,45,4,false); r.digitar.Visible=true; r.digitar:CaptureFocus(); task.wait(.2); r.check("campo de digitacao focado",game.UserInputService:GetFocusedTextBox()==r.digitar); return "digitando"')
    for name in ["Four", "Space", "Zero"]:
        key(name)
    check('r.check("digitar nao escolhe nem passa",#r.envios==3 and f.Visible); r.digitar:ReleaseFocus(); r.digitar.Visible=false; return "chat protegido"')
    key("Zero")
    check('r.check("zero passa depois de sair do chat",#r.envios==4 and not f.Visible); r.mostrar(105,1.2,1,false); r.check("prazo curto sinaliza urgencia",b.Contagem.TextColor3==require(game.ReplicatedStorage.Shared.Estilo).PERIGO); task.wait(1.4); r.check("expira visualmente sem resposta inventada",not f.Visible and #r.envios==4); r.mostrar(106,.8,1,false); r.mostrar(107,45,2,false); r.fechar(106); task.wait(.8); r.check("fecho e prazo antigos nao fecham nova pergunta",f.Visible); return "prazos"')
    press(root+'.Passar')
    check('r.check("nova pergunta conserva o id",r.envios[#r.envios].dados.id==107); r.mostrar(108,45,1,false); r.fechar(108); r.check("fecho do servidor esconde pergunta",not f.Visible); r.mostrar(109,45,1,false); for _,cb in r.callbacks do cb({combat={active=false}}) end; r.check("fim do combate limpa pergunta",not f.Visible); g:Destroy(); r.recriar(); r.mostrar(110,45,4,false); return "recriou"')
    key("Four")
    check('r.check("recriar nao duplica ouvintes",#r.envios==6 and r.envios[6].dados.id==110); game.ReplicatedStorage.G4Teste.Canal:FireServer("pendente",{}); task.wait(.4); r.check("pergunta real do servidor aparece",f.Visible and b.Opcoes.Descricao.Text=="Pergunta real do servidor"); return "pendente real"')
    press(root+'.Opcoes.Opcao_1')
    result = server('task.wait(.2); local r=shared.G4Servidor; assert(r.concluido and r.resultado=="reacao_real"); assert(r.respostas[#r.respostas].erro==nil); return "ReacoesService: escolha aceita"')
    print(result, flush=True)
    check('r.check("escolha real fecha UI",not f.Visible); game.ReplicatedStorage.G4Teste.Canal:FireServer("pendente",{}); task.wait(.4); return "passar real"')
    press(root+'.Passar')
    print(server('task.wait(.2); local r=shared.G4Servidor; assert(r.concluido and r.resultado==nil); assert(r.respostas[#r.respostas].erro==nil); return "ReacoesService: passar aceito"'), flush=True)
    check('r.antesTimeout=#r.envios; game.ReplicatedStorage.G4Teste.Canal:FireServer("pendente",{}); task.wait(.4); return "timeout real"')
    time.sleep(8.5)
    print(server('assert(shared.G4Servidor.concluido and shared.G4Servidor.resultado==nil); return "ReacoesService: prazo encerrado sem escolha"'), flush=True)
    check('r.check("timeout real fecha UI sem enviar",not f.Visible and #r.envios==r.antesTimeout); r.gui:Destroy(); r.caixaGui:Destroy(); return "limpo"')
    result = lua('local r=shared.G4; return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")')
    print(result, flush=True)
    assert "FINAL 0" in result and "FALHA " not in result, result
    print("Console:", call("get_console_output"), flush=True)
finally:
    if iniciou:
        print(call("start_stop_play", is_start=False), flush=True)
        print(call("get_studio_state"), flush=True)
    c.close()

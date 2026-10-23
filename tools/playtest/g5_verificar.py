"""Árvores: specs de serviço isolado e UI/execução no treino real."""
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
    print(lua('local r=shared.G5; local g=game.Players.LocalPlayer.PlayerGui.Arvores; local p=g:FindFirstChild("Pagina",true); '+code), flush=True)

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

    print(lua('local R={falhas=0,linhas={}}; shared.G5=R; function R.check(nome,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..nome); if not ok then R.falhas+=1 end end; local remote=game.ReplicatedStorage.Mesa; R.con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then R.snap=d elseif k=="efeito" then R.efeito=d end end); remote:FireServer("escolherPersonagem",{id="mago-de-fogo"}); task.wait(.5); remote:FireServer("iniciarTreino",{}); task.wait(2); return "treino real"'),flush=True)
    root='game.Players.LocalPlayer.PlayerGui'
    key('T')
    time.sleep(.7)
    check('r.check("arvore real abre",g.Enabled); r.check("guia Fogo real",p.ComoJogar~=nil); local textos={}; for _,o in p.ComoJogar:GetChildren() do if o:IsA("TextLabel") then table.insert(textos,o.Text); r.check("guia Fogo texto completo",o.TextFits) end end; r.check("guia reconhece tecnicas conhecidas",string.find(table.concat(textos),"Conhecida",1,true)~=nil); return "Fogo"')
    capture('g5_arvore_fogo')
    for arvore in ['agua','vento','terra']:
        press(root+'.Arvores:FindFirstChild("Arvore_'+arvore+'",true)')
        check('r.check("guia '+arvore+'",p.ComoJogar~=nil); local textos={}; for _,o in p.ComoJogar:GetChildren() do if o:IsA("TextLabel") then table.insert(textos,o.Text); r.check("texto '+arvore+' completo",o.TextFits) end end; r.check("indica aprendizado '+arvore+'",string.find(table.concat(textos),"Aprenda abaixo",1,true)~=nil); return "'+arvore+'"')
    press(root+'.Arvores:FindFirstChild("Arvore_fogo",true)')
    print(lua('local p=game.Players.LocalPlayer.PlayerGui.Arvores:FindFirstChild("Pagina",true); local card=p:FindFirstChild("Carta_fagulha",true); assert(card); p.CanvasPosition=Vector2.new(0,card.AbsolutePosition.Y-p.AbsolutePosition.Y+p.CanvasPosition.Y-8); task.wait(.4); local r=shared.G5; r.check("Fagulha mostra regra do jogo",card.NoJogo and string.find(card.NoJogo.Text,"1d4",1,true)~=nil); r.check("Fagulha texto completo",card.NoJogo.TextFits); local livro=false; for _,o in card:GetChildren() do if o:IsA("TextLabel") and string.find(o.Text,"NO LIVRO",1,true) then livro=true end end; r.check("Fagulha preserva texto do livro separado",livro); return "adaptacao"'),flush=True)
    capture('g5_fagulha_consulta')
    key('T')
    press(root+'.AcoesDoTurno.Barra.Grupos.Golpes')
    press(root+'.AcoesDoTurno.Barra.Cartas.Carta_fagulha')
    print(lua('local r=shared.G5; r.check("selecionar Fagulha nao cobra",r.snap.jogo.acoes.usadas==0); r.check("Fagulha tem mira de casas",#workspace.MiraLocal:GetChildren()>0); r.antesMana=nil; for _,t in r.snap.tokens do if t.id==r.snap.combat.turnId then r.me=t; r.antesMana=t.mana end end; r.fx,r.fz=r.me.x+1,r.me.z; game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.me.id,habilidadeId="ability/fogo/Principiante/fagulha",x=r.fx,z=r.fz}); task.wait(.7); r.check("Fagulha recebe recibo real",r.efeito and r.efeito.habilidadeId=="ability/fogo/Principiante/fagulha" and #r.efeito.casas==1); r.check("Fagulha cobra uma Acao real",r.snap.jogo.acoes.usadas==1); for _,t in r.snap.tokens do if t.id==r.me.id then r.check("Fagulha cobra um PM real",t.mana==r.antesMana-1) end end; return "Fagulha real"'),flush=True)
    print(lua('task.wait(.6); local r=shared.G5; local z=r.snap.jogo.muros[1]; assert(z); local m=workspace.MurosDeFogo:FindFirstChild(z.id); r.check("perigo baixo renderizado",m and m.Chama.Size.Y<1); r.check("chama pequena renderizada",m and m.Chama.Fire.Size==3); r.zid=z.id; local aviso=game.Players.LocalPlayer.PlayerGui.PerigosMesa:FindFirstChild("Perigo_"..z.id); r.check("aviso de dano renderizado",aviso and aviso.Visible and aviso.Text=="Fagulha • 1d4 ao entrar" and aviso.TextFits); return "braseiro"'),flush=True)
    if lua('return tostring(game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.CancelarMira.Visible)').strip() == 'true':
        press(root+'.AcoesDoTurno.Barra.Controles.CancelarMira')
    capture('g5_fagulha_real')
    print(lua('local r=shared.G5; local antes=r.snap.jogo.acoes.usadas; local mana; for _,t in r.snap.tokens do if t.id==r.me.id then mana=t.mana end end; game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.me.id,habilidadeId="ability/fogo/Principiante/fagulha",x=r.me.x+7,z=r.me.z}); task.wait(.4); r.check("fora de alcance nao cobra real",r.snap.jogo.acoes.usadas==antes); for _,t in r.snap.tokens do if t.id==r.me.id then r.check("recusa preserva mana real",t.mana==mana) end end; game.ReplicatedStorage.Mesa:FireServer("sairPartida",{}); task.wait(1.8); r.check("encerrar remove aviso de perigo",game.Players.LocalPlayer.PlayerGui.PerigosMesa:FindFirstChild("Perigo_"..r.zid)==nil); r.con:Disconnect(); return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'),flush=True)
    result=lua('return "FINAL "..shared.G5.falhas')
    assert 'FINAL 0' in result,result
    print('Console:',call('get_console_output'),flush=True)
finally:
    if iniciou:
        print("Console final:",call("get_console_output"),flush=True)
        print(call("start_stop_play",is_start=False),flush=True)
        print(call("get_studio_state"),flush=True)
    c.close()

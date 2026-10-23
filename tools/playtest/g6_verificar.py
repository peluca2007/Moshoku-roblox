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
    print(lua('local r=shared.G6; local g=game.Players.LocalPlayer.PlayerGui.Arvores; local p=g:FindFirstChild("Pagina",true); '+code), flush=True)

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
    studios=json.loads(c.call("list_roblox_studios",{})["text"])["studios"]
    sid=next(s["id"] for s in studios if s["name"]=="Moshoku-Prototipo.rbxlx")
    assert "- Current Studio Mode: Edit" in call("get_studio_state").splitlines()
    items=studio_sync.collect()
    for start in range(0,len(items),6):
        assert call("execute_luau",datamodel_type="Edit",code=studio_sync.chunk_code(items[start:start+6])).startswith("alterados:")
    print("Fontes sincronizadas",flush=True)
    print(call("start_stop_play",is_start=True),flush=True); iniciou=True
    time.sleep(8)
    result=server('local r=game.ServerScriptService.Server; local p,f=require(r.TestRunner).run(r.tests); return p.." specs / "..f.." falhas"')
    print(result,flush=True)
    print("Console:",call("get_console_output"),flush=True)
    assert " / 0 falhas" in result,result

    root='game.Players.LocalPlayer.PlayerGui'
    print(lua('local R={falhas=0,linhas={}}; shared.G6=R; function R.check(nome,ok) table.insert(R.linhas,(if ok then "OK " else "FALHA ")..nome); if not ok then R.falhas+=1 end end; local remote=game.ReplicatedStorage.Mesa; R.con=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then R.snap=d elseif k=="efeito" then R.efeito=d end end); remote:FireServer("escolherPersonagem",{id="ladina"}); task.wait(.5); remote:FireServer("iniciarTreino",{}); task.wait(2); R.id=R.snap.combat.turnId; return "Treino Ladina"'),flush=True)
    print(lua('local r=shared.G6;for _,t in r.snap.tokens do if t.x==10 and t.z==8 then r.observador=t.id end end;game.ReplicatedStorage.Mesa:FireServer("move",{id=r.observador,x=10,z=12});task.wait(.6);game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.id,habilidadeId="mesa/esconder"});task.wait(.4);r.check("visao de frente recusa sem custo real",r.snap.jogo.acoes.usadas==0);return "frente"'),flush=True)
    key('M')
    press(root+'.AcoesDoTurno.Barra.Grupos.Apoio')
    pos=json.loads(lua('local o=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Cartas:FindFirstChild("Carta_mesa/esconder"); local p=o.AbsolutePosition+Vector2.new(30,24); return game.HttpService:JSONEncode({p.X,p.Y})'))
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='moveTo',x=round(pos[0]),y=round(pos[1]))]); time.sleep(.4)
    print(lua('local r=shared.G6;local g=game.Players.LocalPlayer.PlayerGui.AcoesDoTurno; r.check("hover abre consulta",g.TooltipAcao.Visible);r.check("hover mostra cone e regra",string.find(g.TooltipAcao.Conteudo.Texto.Text,"90°",1,true)~=nil);r.check("hover mostra casas vigiadas",#workspace.VisaoFurtivaLocal:GetChildren()>0);r.check("hover nao cobra",r.snap.jogo.acoes.usadas==0);r.check("perfil do treino",r.snap.tokens[1].balanceamentoJogo==true);return "hover"'),flush=True)
    print(lua('local r=shared.G6;r.check("previa marca a casa vigiada",workspace.VisaoFurtivaLocal:FindFirstChild("Vigiada_10:15")~=nil);game.ReplicatedStorage.Mesa:FireServer("move",{id=r.observador,x=10,z=16});task.wait(.6);r.check("virar costas limpa casa da previa",workspace.VisaoFurtivaLocal:FindFirstChild("Vigiada_10:15")==nil);return "costas"'),flush=True)
    capture('g6_ladina_hover')
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='moveTo',x=30,y=140)]);time.sleep(.4)
    print(lua('local r=shared.G6;r.check("sair do hover limpa previa",#workspace.VisaoFurtivaLocal:GetChildren()==0);r.check("sair do hover fecha consulta",not game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.TooltipAcao.Visible);return "limpeza"'),flush=True)
    press(root+'.AcoesDoTurno.Barra.Cartas:FindFirstChild("Carta_mesa/esconder")')
    press(root+'.AcoesDoTurno.Barra.Controles.ConfirmarAcao')
    print(lua('task.wait(.5);local r=shared.G6;local escondido=false;for _,t in r.snap.tokens do if t.id==r.id then for _,c in t.conditions do if c.id=="escondido" then escondido=true end end end end;r.check("Esconder real garantido",escondido);r.check("Esconder cobra uma Acao",r.snap.jogo.acoes.usadas==1);game.ReplicatedStorage.Mesa:FireServer("conditionAdd",{id=r.id,condition="caido"});task.wait(.5);r.check("Levantar visivel",game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.Levantar.Visible);return "Caido"'),flush=True)
    print(lua('task.wait(.6);local r=shared.G6;local root=game.Players.LocalPlayer.Character.HumanoidRootPart;r.check("Caido horizontal estavel",root.CFrame.UpVector.Y>.99 and math.abs((root.Parent:FindFirstChild("LowerTorso") or root.Parent:FindFirstChild("Torso")).CFrame.UpVector.Y)<.1);r.check("Caido raiz ancorada",root.Anchored);return "pose caida"'),flush=True)
    capture('g6_caido')
    press(root+'.AcoesDoTurno.Barra.Controles.Levantar')
    print(lua('task.wait(.8);local r=shared.G6;local root=game.Players.LocalPlayer.Character.HumanoidRootPart;r.check("Levantar restaura pose",root.CFrame.UpVector.Y>.99 and (root.Parent:FindFirstChild("LowerTorso") or root.Parent:FindFirstChild("Torso")).CFrame.UpVector.Y>.95);r.check("Levantar paga uma Acao",r.snap.jogo.acoes.usadas==2);r.check("metade do movimento disponivel",r.snap.jogo.acoes.passosLivres>0);r.check("botao Levantar some",not game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.Levantar.Visible);game.ReplicatedStorage.Mesa:FireServer("move",{id=r.id,x=10,z=14,andar=true});task.wait(.7);r.check("andar apos levantar nao cobra de novo",r.snap.jogo.acoes.usadas==2);return "recuperacao"'),flush=True)
    print(lua('local r=shared.G6;game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});task.wait(1.8);game.ReplicatedStorage.Mesa:FireServer("escolherPersonagem",{id="guerreiro-do-norte"});task.wait(.5);game.ReplicatedStorage.Mesa:FireServer("iniciarTreino",{});task.wait(2);r.id=r.snap.combat.turnId;for _,t in r.snap.tokens do if t.x==10 and t.z==8 then r.boneco=t.id end end;game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.id,habilidadeId="ability/deus-do-norte/Principiante/arremesso-de-espada",alvoId=r.boneco});task.wait(.8);r.check("arremesso deixa arma real",#r.snap.jogo.objetos==1);r.check("arma desenhada com lamina cabo e guarda",#workspace.ArmasNoChao:GetChildren()==1 and workspace.ArmasNoChao:GetChildren()[1]:FindFirstChild("Guarda")~=nil);game.ReplicatedStorage.Mesa:FireServer("move",{id=r.id,x=10,z=9,andar=true});task.wait(.8);game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.id,habilidadeId="mesa/pegar-arma",x=10,z=8});task.wait(.7);r.check("recuperar arma remove objeto real",#r.snap.jogo.objetos==0 and #workspace.ArmasNoChao:GetChildren()==0);return "arma"'),flush=True)
    print(lua('local r=shared.G6;game.ReplicatedStorage.Mesa:FireServer("nextTurn",{expectedId=r.id,expectedTurn=r.snap.combat.turn});task.wait(2);game.ReplicatedStorage.Mesa:FireServer("conditionAdd",{id=r.id,condition="caido"});task.wait(.4);game.ReplicatedStorage.Mesa:FireServer("adjust",{id=r.id,field="pv",delta=-100});task.wait(.8);r.check("zero PV nao oferece Levantar",not game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.Levantar.Visible);game.ReplicatedStorage.Mesa:FireServer("criarPremontado",{id="guerreiro-do-norte",ownerUserId=game.Players.LocalPlayer.UserId,x=11,z=9});task.wait(.7);local aux;for _,t in r.snap.tokens do if t.id~=r.id and t.ownerUserId==game.Players.LocalPlayer.UserId then aux=t.id end end;assert(aux,"auxiliar");game.ReplicatedStorage.Mesa:FireServer("combatStart",{entries={{id=aux,initiative=20},{id=r.id,initiative=10}}});task.wait(.5);game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=aux,habilidadeId="ability/deus-do-norte/Principiante/primeiros-socorros-de-campo",alvoId=r.id});task.wait(.9);local hp;for _,t in r.snap.tokens do if t.id==r.id then hp=t.pv end end;r.check("cura real recupera PV",hp and hp>0);r.check("cura real restaura avatar",game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame.UpVector.Y>.99);return "cura de zero"'),flush=True)
    capture('g6_recuperado')
    print(lua('local r=shared.G6;game.ReplicatedStorage.Mesa:FireServer("sairPartida",{});task.wait(1.5);r.check("saida limpa cones",#workspace.VisaoFurtivaLocal:GetChildren()==0);r.con:Disconnect();return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'),flush=True)
    result=lua('return "FINAL "..shared.G6.falhas');assert 'FINAL 0' in result,result
finally:
    if iniciou:
        print("Console final:",call("get_console_output"),flush=True)
        print(call("start_stop_play",is_start=False),flush=True)
        print(call("get_studio_state"),flush=True)
    c.close()

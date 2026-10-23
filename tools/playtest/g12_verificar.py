"""G12: áreas por cliques reais, Ladino e modelos."""
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

c = Client()
sid, iniciou = None, False
base = Path(__file__).parent

def call(tool, **args):
    r = c.call(tool, dict(studio_id=sid, **args), timeout=60)
    if r.get("isError") or "erro" in r:
        raise RuntimeError(r)
    return r["text"]

def lua(code):
    return call("execute_luau", datamodel_type="Client", code='task.delay(.15,function() workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable end);'+code)

def press(path):
    pos = json.loads(lua('local o=' + path + '; local a=o.Parent; while a and not a:IsA("ScrollingFrame") do a=a.Parent end; if a then local y=o.AbsolutePosition.Y-a.AbsolutePosition.Y; if y<0 then a.CanvasPosition+=Vector2.new(0,y) elseif y+o.AbsoluteSize.Y>a.AbsoluteSize.Y then a.CanvasPosition+=Vector2.new(0,y+o.AbsoluteSize.Y-a.AbsoluteSize.Y) end; task.wait(.2) end; local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({p.X,p.Y})'))
    call("user_mouse_input", datamodel_type="Client", actions=[
        dict(action="mouseButtonDown", mouse_button="left", x=round(pos[0]), y=round(pos[1])),
        dict(action="mouseButtonUp", mouse_button="left", x=round(pos[0]), y=round(pos[1]))])
    time.sleep(.2)

def cell(x,z):
    time.sleep(.5)
    pos=json.loads(lua(f'local p=require(game.ReplicatedStorage.Shared.MesaProtocol).cellCenter({x},{z});local v,ok=workspace.CurrentCamera:WorldToViewportPoint(p);assert(ok,"casa fora da tela");return game.HttpService:JSONEncode({{v.X,v.Y-game:GetService("GuiService"):GetGuiInset().Y}})'))
    time.sleep(.4)
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonDown',mouse_button='left',x=round(pos[0]),y=round(pos[1])),dict(action='mouseButtonUp',mouse_button='left',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.4)
    print('CLICK',x,z,pos,lua('return game.HttpService:JSONEncode(shared.G12.click)'),flush=True)

def capture(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m: shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))

try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios']
    sid=next(s['id'] for s in studios if s['name']=='Moshoku-Prototipo.rbxlx')
    assert '- Current Studio Mode: Edit' in call('get_studio_state').splitlines()
    items=studio_sync.collect()
    for i in range(0,len(items),6): assert call('execute_luau',datamodel_type='Edit',code=studio_sync.chunk_code(items[i:i+6])).startswith('alterados:')
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(8)
    result=call('execute_luau',datamodel_type='Server',code='local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);return p.." specs / "..f.." falhas"');print(result,flush=True)
    if ' / 0 falhas' not in result: print(call('get_console_output'),flush=True);raise AssertionError(result)
    print(lua('''local r={falhas=0,linhas={}};shared.G12=r;function r.check(n,ok) table.insert(r.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then r.falhas+=1 end end;local U=game:GetService("UserInputService");r.mouse=U.InputBegan:Connect(function(i,g) if i.UserInputType==Enum.UserInputType.MouseButton1 then local m=U:GetMouseLocation();local ray=workspace.CurrentCamera:ViewportPointToRay(m.X,m.Y);local pos=ray.Origin+ray.Direction*((1-ray.Origin.Y)/ray.Direction.Y);local x,z=require(game.ReplicatedStorage.Shared.MesaProtocol).cellAt(pos);r.click={x=x,z=z,mx=m.X,my=m.Y,gp=g} end end);local re=game.ReplicatedStorage.Mesa;r.con=re.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.snap=d elseif k=="log" and d.tone=="erro" then r.erro=d.text end end);re:FireServer("escolherPersonagem",{id="mago-de-fogo"});task.wait(.5);re:FireServer("iniciarTreino",{});task.wait(2);function r.find(id) for _,t in r.snap.tokens do if t.id==id then return t end end end;r.me=r.find(r.snap.combat.turnId);r.mana=r.me.mana;r.x,r.z=r.me.x,r.me.z;r.check("mago sem esconder",not table.find(r.me.habilidades,"mesa/esconder"));return game.HttpService:JSONEncode({r.x,r.z})'''),flush=True)
    print(lua('local cs={};for _,o in game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Cartas:GetChildren() do table.insert(cs,o.Name) end;return game.HttpService:JSONEncode({cartas=cs,ficha=shared.G12.me.name,habilidades=shared.G12.me.habilidades,erro=shared.G12.erro})'),flush=True)
    root='game.Players.LocalPlayer.PlayerGui'
    press(root+'.AcoesDoTurno.Barra.Cartas["Carta_muro-de-chamas"]')
    coords=json.loads(lua('return game.HttpService:JSONEncode({shared.G12.x,shared.G12.z})'));x,z=coords
    cell(x+1,z)
    print(lua('local r=shared.G12;r.check("primeiro clique fixa inicio",game.Players.LocalPlayer.PlayerGui.MiraTatica.Alvo.Text:find("2. Aponte",1,true)~=nil);r.check("inicio nao gasta",r.snap.jogo.acoes.usadas==0 and r.find(r.me.id).mana==r.mana);return "Inicio"'),flush=True)
    cell(x+4,z)
    print(lua('local r=shared.G12;r.check("segundo clique fixa fim",game.Players.LocalPlayer.PlayerGui.MiraTatica.Alvo.Text:find("3. Confirmar",1,true)~=nil);r.check("previa quatro casas",#workspace.MiraLocal.AreaPrevista:GetChildren()==4);r.check("confirmacao visivel",game.Players.LocalPlayer.PlayerGui.AcoesDoTurno.Barra.Controles.ConfirmarAcao.Visible);r.check("desenho nao gasta",r.snap.jogo.acoes.usadas==0);return "Previa"'),flush=True)
    capture('g12_muralha_previa')
    press(root+'.AcoesDoTurno.Barra.Controles.ConfirmarAcao');time.sleep(.7)
    print(lua('local r=shared.G12;r.check("muralha real quatro casas",#r.snap.jogo.muros==1 and #r.snap.jogo.muros[1].casas==4);r.check("custo duas acoes tres PM",r.snap.jogo.acoes.usadas==2 and r.find(r.me.id).mana==r.mana-3);r.check("mira limpa",not game.Players.LocalPlayer.PlayerGui.MiraTatica.Alvo.Visible and #workspace.MiraLocal.AreaPrevista:GetChildren()==0);game.ReplicatedStorage.Mesa:FireServer("usarHabilidade",{tokenId=r.me.id,habilidadeId="mesa/esconder"});task.wait(.5);r.check("nao ladino recusado sem custo",r.erro~=nil and r.snap.jogo.acoes.usadas==2);return "Muralha confirmada"'),flush=True)
    press(root+'.AcoesDoTurno.Barra.Grupos.Apoio')
    press(root+'.AcoesDoTurno.Barra.Cartas["Carta_clarao"]')
    print(lua('local r=shared.G12;r.check("circulo tem previa",#workspace.MiraLocal.AreaPrevista:GetChildren()>1);r.check("circulo aguarda confirmar",r.snap.jogo.acoes.usadas==2);return "Circulo"'),flush=True)
    press(root+'.AcoesDoTurno.Barra.Controles.CancelarMira')
    print(lua('''local r=shared.G12;local re=game.ReplicatedStorage.Mesa;re:FireServer("sairPartida",{});task.wait(.5);re:FireServer("escolherPersonagem",{id="ladina"});task.wait(.5);re:FireServer("iniciarTreino",{});task.wait(1);local t=r.find(r.snap.combat.turnId);r.check("ladino recebe esconder",t and table.find(t.habilidades,"mesa/esconder")~=nil);re:FireServer("sairPartida",{});task.wait(.5);re:FireServer("escolherPersonagem",{id="bardo"});task.wait(.5);re:FireServer("iniciarLuta",{nivel=2});task.wait(3);return "Urso"'''),flush=True)
    print(call('execute_luau',datamodel_type='Server',code='''local pasta=workspace.CorposDeCriatura;local urso;for _,m in pasta:GetChildren() do if m:FindFirstChild("PresaVermelha") then urso=m end end;assert(urso,"urso ausente");local patas=0;for _,p in urso:GetChildren() do if p.Name=="Pata" then patas+=1;assert(not p.CanCollide and not p.CanQuery and not p.CanTouch) end end;assert(patas==4);local pata,perna;for _,p in urso:GetChildren() do local d=p:GetAttribute("Deslocamento");if d and d.Position.X<0 and d.Position.Z<0 then if p.Name=="Pata" then pata=p elseif p.Name=="PernaFrente" then perna=p end end end;shared.G12Urso={id=urso.Name,pata=pata,perna=perna,rel=perna.CFrame:ToObjectSpace(pata.CFrame),amostras=0,maxErro=0,inicio=urso.PrimaryPart.Position};local r=shared.G12Urso;r.con=game.RunService.Heartbeat:Connect(function() local dist=(urso.PrimaryPart.Position-r.inicio).Magnitude;if dist>.05 and dist<4.95 then r.amostras+=1;r.maxErro=math.max(r.maxErro,(perna.CFrame:ToObjectSpace(pata.CFrame).Position-r.rel.Position).Magnitude) end end);return "Urso: 4 patas, presas e sem colisao"'''),flush=True)
    print(lua('local r=shared.G12;for _,t in r.snap.tokens do if t.criatura and t.name:lower():find("urso",1,true) then game.ReplicatedStorage.Mesa:FireServer("move",{id=t.id,x=t.x+1,z=t.z});break end end;return "Caminhada"'),flush=True);time.sleep(.15)
    print(call('execute_luau',datamodel_type='Server',code='local r=shared.G12Urso;local atual=r.perna.CFrame:ToObjectSpace(r.pata.CFrame);r.con:Disconnect();assert((atual.Position-r.rel.Position).Magnitude<.02);assert(r.amostras>0 and r.maxErro<.02);return "Patas acompanham o pivo das pernas: "..r.amostras.." quadros"'),flush=True)
    call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code='M')])
    print(lua('''local r=shared.G12;for _,g in game.Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") then g.Enabled=false end end;local m;for _,v in workspace.CorposDeCriatura:GetChildren() do if v:FindFirstChild("PresaVermelha") then m=v end end;assert(m);r.fotoModelo=m;r.foto=game.RunService.RenderStepped:Connect(function() local p=r.fotoModelo:GetPivot().Position+Vector3.new(0,3,0);workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable;workspace.CurrentCamera.CFrame=CFrame.lookAt(p+Vector3.new(12,8,14),p) end);return "Camera urso"'''),flush=True);time.sleep(.5);capture('g12_urso')
    print(lua('local r=shared.G12;for _,m in workspace.CorposDeCriatura:GetChildren() do if m:GetAttribute("DetalhesVisuais") then r.fotoModelo=m;break end end;return "Camera goblin"'),flush=True);time.sleep(.5);capture('g12_goblin')
    print(lua('local r=shared.G12;r.foto:Disconnect();r.con:Disconnect();return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'),flush=True)
    assert lua('return shared.G12.falhas').strip()=='0'
    print('Console:',call('get_console_output'),flush=True)
finally:
    if iniciou: print(lua('local r=shared.G12;return r and table.concat(r.linhas,"\\n") or "sem bancada"'),flush=True);print(call('get_console_output'),flush=True);print(call('start_stop_play',is_start=False),flush=True);print(call('get_studio_state'),flush=True)
    c.close()


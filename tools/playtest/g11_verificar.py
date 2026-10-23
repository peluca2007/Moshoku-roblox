"""G11: suíte completa, apresentação no cliente, corpos e resultado real."""
import json, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client
import studio_sync
c=Client(); sid=None; iniciou=False; base=Path(__file__).parent
def call(tool,**args):
    r=c.call(tool,dict(studio_id=sid,**args),timeout=60)
    if r.get('isError') or 'erro' in r: raise RuntimeError(r)
    return r['text']
def lua(code): return call('execute_luau',datamodel_type='Client',code=code)
def press(path):
    pos=json.loads(lua('local o='+path+';local p=o.AbsolutePosition+o.AbsoluteSize/2;return game.HttpService:JSONEncode({p.X,p.Y})'))
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonDown',mouse_button='left',x=round(pos[0]),y=round(pos[1])),dict(action='mouseButtonUp',mouse_button='left',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.3)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m: shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios']
    sid=next(s['id'] for s in studios if s['name']=='Moshoku-Prototipo.rbxlx')
    assert '- Current Studio Mode: Edit' in call('get_studio_state').splitlines()
    items=studio_sync.collect()
    for i in range(0,len(items),6): assert call('execute_luau',datamodel_type='Edit',code=studio_sync.chunk_code(items[i:i+6])).startswith('alterados:')
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(8)
    r=call('execute_luau',datamodel_type='Server',code='local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);return p.." specs / "..f.." falhas"');print(r,flush=True);assert ' / 0 falhas' in r
    print(lua('''
local r={falhas=0,linhas={}};shared.G11=r
function r.check(n,ok) table.insert(r.linhas,(if ok then "OK " else "FALHA ")..n);if not ok then r.falhas+=1 end end
local pg=game.Players.LocalPlayer.PlayerGui;pg.InicioJogo.MenuInicial.Visible=false
local C=game.Players.LocalPlayer.PlayerScripts.Client
r.snap={tokens={{id="eu",name="Herói",x=10,z=10},{id="alvo",name="Goblin",x=11,z=10}},map={terrain={}},combat={active=false}}
r.mira={tokenId="eu",modo="lista",tipo="ataque",alcanceCasas=2,maxAlvos=2,alvoIds={"alvo"}}
r.x,r.z=11,10
local st={mira=function() return r.mira end,snapshot=function() return r.snap end,tableView=function() return true end,findToken=function(id) for _,t in r.snap.tokens do if t.id==id then return t end end end,onMira=function(f) r.mudou=f end,onSnapshot=function(f) r.novo=f end}
r.view=require(C.MiraView).start(st,function() return r.x,r.z end);r.view.Name="MiraBancada";task.wait(.3)
r.check("nome distancia selecao",r.view.Alvo.Visible and r.view.Alvo.Text:find("Goblin",1,true) and r.view.Alvo.Text:find("1/2",1,true) and r.view.Alvo.Text:find("Selecionado",1,true))
r.x=15;r.mudou();task.wait(.2);r.check("fora alcance",r.view.Alvo.Text:find("Fora do alcance",1,true)~=nil)
r.x=11;r.snap.tokens[1].x=8;r.novo();task.wait(.2);r.check("origem atualizada no snapshot",r.view.Alvo.Text:find("3/2",1,true)~=nil)
r.mira=nil;r.mudou();task.wait(.2);r.check("cancelamento limpa",not r.view.Alvo.Visible)
r.view:Destroy();r.check("callbacks apos destruir",pcall(r.mudou) and pcall(r.novo))
r.result=require(C.ResultadoView).start({onEncontro=function(f) r.fim=f end,onSnapshot=function(f) r.snapshot=f end,setMira=function(v) r.limpou=v==nil end},{abrirJogar=function() r.abriu=true end});r.result.Name="ResultadoBancada"
r.fim({resultado="vitoria",modo="luta"});task.wait(.3);r.check("vitoria limpa mira",r.limpou and r.result.Fundo.Painel.Titulo.Text=="VITÓRIA")
return "Bancada iniciada"
'''),flush=True)
    time.sleep(3);shot('g11_resultado')
    print(lua('shared.G11.check("resultado persistente",shared.G11.result.Fundo.Visible);return "persistente"'),flush=True)
    press('game.Players.LocalPlayer.PlayerGui.ResultadoBancada.Fundo.Painel.Proxima')
    print(lua('''local r=shared.G11;r.check("proxima por clique",r.abriu and not r.result.Fundo.Visible);r.fim({resultado="derrota"});r.check("derrota",r.result.Fundo.Painel.Titulo.Text=="DERROTA");r.fim({modo="duelo",resultado="duelo",vencedor="Equipe 1"});r.check("vencedor pvp",r.result.Fundo.Painel.Detalhe.Text=="Equipe 1 venceu!");r.snapshot({combat={active=true}});r.check("nova partida fecha resultado",not r.result.Fundo.Visible);r.result:Destroy();r.check("fim depois de destruir",pcall(r.fim,{resultado="vitoria"}));local re=game.ReplicatedStorage.Mesa;r.con=re.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.real=d elseif k=="encontro" then r.evento=d end end);re:FireServer("escolherPersonagem",{id="bardo"});task.wait(.5);re:FireServer("iniciarLuta",{nivel=1,encontro="lobo"});task.wait(3);r.check("desafio real iniciou",r.real and r.real.combat.active);return "Desafio"'''),flush=True)
    print(call('execute_luau',datamodel_type='Server',code='''local p=workspace.CorposDeCriatura;local gob,lobo=0,0;for _,m in p:GetChildren() do if m:GetAttribute("DetalhesVisuais") then assert(m:FindFirstChild("OrelhaGoblin"));assert(m.Cinto:FindFirstChildOfClass("Weld"));gob+=1 end;if m:FindFirstChild("Juba") then lobo+=1;local n=0;for _,v in m:GetChildren() do if v.Name=="Pata" then n+=1;assert(not v.CanCollide and not v.CanQuery and not v.CanTouch) end end;assert(n==4) end end;assert(gob>0 and lobo>0);return "Modelos reais: "..gob.." goblin / "..lobo.." lobo"'''),flush=True)
    print(lua("""
local r=shared.G11;local C=game.Players.LocalPlayer.PlayerScripts.Client
local st={findToken=function(id) for _,t in r.real.tokens do if t.id==id then return t end end end};local P=require(game.ReplicatedStorage.Shared.MesaProtocol)
local pasta=Instance.new("Folder",workspace);pasta.Name="G11Cenas"
local core=require(C.Coreografia).start(st,pasta,function(s,id,fallback) local t=s.findToken(id);local x,z=if t then t.x else (fallback and fallback[1] or 10),if t then t.z else (fallback and fallback[2] or 10);return P.cellCenter(x,z)+Vector3.new(0,3,0) end)
local caster,target;for _,t in r.real.tokens do if t.avatar then caster=t elseif t.criatura then target=t end end
local char=game.Players.LocalPlayer.Character;local root=char.HumanoidRootPart;local base=root.CFrame
for _,hit in {true,false} do
 r.check(if hit then "cena acerto" else "cena erro",core.tocar({habilidadeId="mesa/ataque-basico",casterId=caster.id,alvos={{id=target.id,acertou=hit,dano=if hit then 5 else 0,critico=hit}}}))
 task.wait(.45);r.check("cena em andamento",core.estado().cenas>0);task.wait(2)
 r.check("cena limpa e raiz preservada",core.estado().cenas==0 and core.estado().pecas==0 and (root.Position-base.Position).Magnitude<.1)
 r.check("corpo real restaurado",char.Head.LocalTransparencyModifier==0)
end
core.destruir();pasta:Destroy();return "Animacoes: acerto critico e erro"
"""),flush=True)
    print(lua('''local r=shared.G11;local re=game.ReplicatedStorage.Mesa;for _,t in r.real.tokens do if t.criatura then re:FireServer("adjust",{id=t.id,field="pv",delta=-999});task.wait(.25) end end;task.wait(3);r.check("fim real confirmado",r.evento and r.evento.resultado=="vitoria");local g=game.Players.LocalPlayer.PlayerGui.ResultadoPartida;r.check("tela real vitoria",g.Fundo.Visible and g.Fundo.Painel.Titulo.Text=="VITÓRIA");return "Resultado real"'''),flush=True)
    shot('g11_vitoria_real')
    press('game.Players.LocalPlayer.PlayerGui.ResultadoPartida.Fundo.Painel.Proxima')
    print(lua('''local r=shared.G11;r.check("menu real reaberto",game.Players.LocalPlayer.PlayerGui.InicioJogo.MenuInicial.Visible);r.con:Disconnect();return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'''),flush=True)
    assert lua('return shared.G11.falhas').strip()=='0'
    print('Console:',call('get_console_output'),flush=True)
finally:
    if iniciou: print(call('start_stop_play',is_start=False),flush=True);print(call('get_studio_state'),flush=True)
    c.close()

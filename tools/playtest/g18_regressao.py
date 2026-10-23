"""Regressão de preparação/câmera/prontidão sobre fonte G18; fecha apenas chat da sessão de teste.
--visual repete o fluxo para capturas, sem reexecutar a suíte completa.
M/guarda de digitação: executar separadamente g18_atalhos.py, com monitor LocalScript persistente.
"""
import json, os, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
os.environ['MOSHOKU_TESTE_JOGADOR']='1'
os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;iniciou=False;base=Path(__file__).parent
def call(tool,**kw):
    r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
    if r.get('isError') or 'erro' in r: raise RuntimeError(r)
    return r['text']
def lua(code,dm='Client'):return call('execute_luau',datamodel_type=dm,code=code)
def key(k):
    action=dict(action='keyPress',key_code=k)
    actions=[action]
    if k=='M':actions=[dict(action='keyDown',key_code=k),dict(action='wait',wait_time_ms=250),dict(action='keyUp',key_code=k)]
    call('user_keyboard_input',datamodel_type='Client',actions=actions)
    time.sleep(.45)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
def aim(path):
    lua('shared.G14.alvo='+path+';shared.G14.aim=true;return "mira"');time.sleep(.7);key('E');lua('shared.G14.aim=false;return "fim mira"');time.sleep(.4)
def paper_pos(name):
    code='''local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;local sc=g.Pagina;local b=sc:FindFirstChild("%s",true) or g:FindFirstChild("%s");local y=b.AbsolutePosition.Y-sc.AbsolutePosition.Y;if y<0 then sc.CanvasPosition+=Vector2.new(0,y) elseif y+b.AbsoluteSize.Y>sc.AbsoluteSize.Y then sc.CanvasPosition+=Vector2.new(0,y+b.AbsoluteSize.Y-sc.AbsoluteSize.Y) end;task.wait(.2);local a=b.AbsolutePosition+b.AbsoluteSize/2;local u=a.X/g.CanvasSize.X;local v=a.Y/g.CanvasSize.Y;local p=g.Adornee;local w=p.CFrame:PointToWorldSpace(Vector3.new(-(u-.5)*p.Size.X,(.5-v)*p.Size.Y,-p.Size.Z/2-.002));local q=workspace.CurrentCamera:WorldToViewportPoint(w);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y})'''%(name,name)
    pos=json.loads(lua(code))
    return [round(pos[0]),round(pos[1])]
def paper_button(name):
    x,y=paper_pos(name)
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=x,y=y)])
    time.sleep(.65)
    print('CLICK',name,x,y,flush=True)
def marker_button(name):
    pos=json.loads(lua('local g=game.Players.LocalPlayer.PlayerGui.MarcadoresInterface;local b=g.Frame:FindFirstChild("'+name+'");local a=b.AbsolutePosition+b.AbsoluteSize/2;local p=g.Adornee;local w=p.CFrame:PointToWorldSpace(Vector3.new(-(a.X/g.CanvasSize.X-.5)*p.Size.X,(.5-a.Y/g.CanvasSize.Y)*p.Size.Y,-p.Size.Z/2-.002));local q=workspace.CurrentCamera:WorldToViewportPoint(w);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y})'))
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.55)
    print('MARCADOR',name,pos,flush=True)

def click_world(path):
    lua('local c=workspace.CurrentCamera;shared.G14.olhar=CFrame.lookAt(c.CFrame.Position,'+path+'.Position);return "olhar objeto"');time.sleep(.6)
    pos=json.loads(lua('local c=workspace.CurrentCamera;local q=c:WorldToViewportPoint('+path+'.Position);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y})'))
    key('L')
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.7)
    lua('shared.G14.olhar=nil;return "livre"');key('L')

def leitura_livre(nome):
    print(lua('''local p=workspace.SalaObjetosLocais.PapelEmMaos;local c=workspace.CurrentCamera;local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={game.Players.LocalPlayer.Character};local livre=true;for _,x in {-.4,0,.4} do for _,y in {-.4,0,.4} do local alvo=p.CFrame:PointToWorldSpace(Vector3.new(p.Size.X*x,p.Size.Y*y,-p.Size.Z/2));local delta=alvo-c.CFrame.Position;local hit=workspace:Raycast(c.CFrame.Position,delta.Unit*(delta.Magnitude+.02),params);if not hit or hit.Instance~=p then livre=false end end end;shared.G14.check("'''+nome+''' sem obstrucao",livre);return "Leitura livre"'''),flush=True)

try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios']
    sid=next(s['id'] for s in studios if 'MoshokuRPGMesa' in s['name'])
    assert 'Mode: Edit' in call('get_studio_state')
    lua('workspace:SetAttribute("MoshokuTesteMestre",nil);return "Edit"','Edit')
    items=studio_sync.collect()
    for i in range(0,len(items),6):
        result=lua(studio_sync.chunk_code(items[i:i+6]),'Edit')
        assert result.startswith('alterados:'),result
    print('Fonte sincronizada',flush=True)
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
    print(lua('local s=game:GetService("StarterGui");local ok=pcall(function() s:SetCore("ChatActive",false) end);game:GetService("TextChatService").ChatWindowConfiguration.Enabled=false;return "Chat fechado apenas nesta sessao de teste: "..tostring(ok)'),flush=True)
    if '--specs' in sys.argv:
        result=lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);return p.." specs / "..f.." falhas"','Server');print(result,flush=True)
        if ' / 0 falhas' not in result:print(call('get_console_output'),flush=True);raise AssertionError(result)
    print(lua('''local r={falhas=0,linhas={},erros={}};shared.G14=r;function r.check(n,v) table.insert(r.linhas,(if v then "OK " else "FALHA ")..n);if not v then r.falhas+=1 end end;r.con=game.ReplicatedStorage.Mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.snap=d elseif k=="log" and d.tone=="erro" then table.insert(r.erros,d.text) end end);game.ReplicatedStorage.Mesa:FireServer("requestSnapshot",{});task.wait(.5);local p=game.Players.LocalPlayer;r.check("sala mestre",r.snap.salaConceitual.mestre==p.UserId);r.check("primeira pessoa",p.CameraMode==Enum.CameraMode.LockFirstPerson);r.check("cabeca oculta",p.Character.Head.LocalTransparencyModifier==1);local corpo=p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso");r.check("corpo visivel",corpo and corpo.LocalTransparencyModifier==0);r.check("bandeja e caderno",workspace.SalaRPG:FindFirstChild("BandejaDados") and workspace.SalaRPG:FindFirstChild("CapaCaderno"));r.check("escudo moldura",workspace.SalaRPG:FindFirstChild("MolduraEscudo")~=nil);game:GetService("RunService"):BindToRenderStep("G14MiraTeste",Enum.RenderPriority.Camera.Value+5,function() if r.olhar then local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=r.olhar end end);return "Sala pronta"'''),flush=True)
    lua('game.ReplicatedStorage.Mesa:FireServer("escolherPersonagem",{id="mago-de-fogo",arma=require(game.ReplicatedStorage.Shared.PersonagensProntos)[1].armas[1].id});return "Escolha"');time.sleep(.6);key('P')
    print(lua('local r=shared.G14;local obj;for _,p in workspace.SalaRPG:GetDescendants() do if p:IsA("BasePart") and p:GetAttribute("SalaObjeto")=="pronto" then obj=p;break end end;assert(obj);local prompt=obj:FindFirstChild("InteragirSala");r.check("prontidao confirmada no servidor",r.snap.salaConceitual.pessoas[1].pronto);r.check("prompt oferece cancelar confirmado",prompt and prompt.ActionText=="Cancelar prontidão");local l=obj:FindFirstChildWhichIsA("TextLabel",true);r.check("selo mostra pronto confirmado",l and l.Text:find("✓ PRONTO",1,true));return "pronto confirmado"'),flush=True)
    key('P')
    print(lua('local r=shared.G14;local obj;for _,p in workspace.SalaRPG:GetDescendants() do if p:IsA("BasePart") and p:GetAttribute("SalaObjeto")=="pronto" then obj=p;break end end;r.check("cancelar prontidao autoritativa",not r.snap.salaConceitual.pessoas[1].pronto);r.check("prompt volta a confirmar",obj.InteragirSala.ActionText=="Confirmar prontidão");return "pronto cancelado"'),flush=True)
    key('P')
    key('C')
    print(lua('local r=shared.G14;local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;r.check("modos explicitos",g.Pagina:FindFirstChild("Modo_treino") and g.Pagina:FindFirstChild("Modo_duelo") and g.Pagina:FindFirstChild("Modo_luta"));r.check("inicio habilitado",g.Pagina.LancarDados.Interactable);return "Preparacao"'),flush=True)
    print(lua('local r=shared.G14;local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;local sc=g.Pagina;sc.CanvasPosition=Vector2.zero;task.wait(.3);game.GuiService.SelectedObject=sc.Abas.Aba_sessao;task.wait(.3);local a=sc.Monstros;sc.CanvasPosition+=Vector2.new(0,math.max(0,a.AbsolutePosition.Y+a.AbsoluteSize.Y-sc.AbsolutePosition.Y-sc.AbsoluteSize.Y));task.wait(.3);for _=1,2 do game.GuiService.SelectedObject=sc.Monstros;task.wait(.2);if game.GuiService.SelectedObject==sc.Monstros then break end end;r.check("foco de bancada em opcao visivel",game.GuiService.SelectedObject==sc.Monstros);game.ReplicatedStorage.Mesa:FireServer("salaConfigurar",{modo="luta",nivel=1,monstros=true});task.wait(.7);local b=game.GuiService.SelectedObject;r.check("foco preservado apos snapshot real",b and b.Name=="Monstros" and b.Parent==sc);r.check("foco real dentro da rolagem",b and b.AbsolutePosition.Y>=sc.AbsolutePosition.Y-1 and b.AbsolutePosition.Y+b.AbsoluteSize.Y<=sc.AbsolutePosition.Y+sc.AbsoluteSize.Y+1);game.GuiService.SelectedObject=nil;sc.CanvasPosition=Vector2.zero;return "Foco producao"'),flush=True)
    leitura_livre('preparacao');shot('g18_regressao_preparacao')
    paper_button('Modo_duelo')
    print(lua('shared.G14.check("pvp solo bloqueado",not game.Players.LocalPlayer.PlayerGui.SalaPapelInterface.Pagina.LancarDados.Interactable);return "PvP bloqueado"'),flush=True)
    paper_button('Modo_luta');paper_button('Aba_sala');paper_button('ArrumarSala')
    print(lua('shared.G14.check("arrumar recolhe",#shared.G14.snap.salaConceitual.papeisSoltos==0);return "Arrumado"'),flush=True)
    paper_button('BrotosTodos');paper_button('GuardarPapel')
    print(lua('shared.G14.check("Brotos aberto",shared.G14.snap.salaConceitual.brincadeiraBrotos.fase=="rolagem");return "Rodada"'),flush=True)
    key('G');time.sleep(1.2)
    print(lua('local r=shared.G14;local s=r.snap.salaConceitual;r.check("rodada real concluida",s.brincadeiraBrotos.fase=="resultado");r.check("mestre nao muda",s.mestre==game.Players.LocalPlayer.UserId);local a=s.brincadeiraBrotos.dados[game.Players.LocalPlayer.UserId] or s.brincadeiraBrotos.dados[tostring(game.Players.LocalPlayer.UserId)];r.check("placar recreativo",workspace.SalaObjetosLocais.PlacarDaMesa.Impressao.PlacarBrotos.Text:find("Venceu:",1,true)~=nil);return "Brotos"'),flush=True)
    shot('g18_regressao_brotos')
    # ADM pelo remoto real, incluindo limite de frequência existente.
    print(lua('game.ReplicatedStorage.ComandosAdmin:FireServer({comando="brotos"});task.wait(.7);shared.G14.check("ADM brotos real",shared.G14.snap.salaConceitual.brincadeiraBrotos.fase=="rolagem");game.ReplicatedStorage.Mesa:FireServer("salaBrotos",{});task.wait(.5);return "Admin"'),flush=True)
    key('C');paper_button('Aba_sessao')
    lua('local r=shared.G14;r.trans={frames=0,fora=0,maxY=0,escuro=false};game:GetService("RunService").RenderStepped:Connect(function() if r.snap.salaConceitual.transicao then local c=workspace.CurrentCamera;r.trans.frames+=1;r.trans.maxY=math.max(r.trans.maxY,c.CFrame.Position.Y);if math.abs(c.CFrame.Position.X-250)>25 then r.trans.fora+=1 end;local t=game.Players.LocalPlayer.PlayerGui.TransicaoSala:FindFirstChildOfClass("Frame");if t.Visible and t.BackgroundTransparency<.05 then r.trans.escuro=true end end end);return "Amostragem"')
    paper_button('LancarDados');time.sleep(3.5)
    print(lua('local r=shared.G14;r.check("transicao permanece na mesa",r.trans.frames>10 and r.trans.fora==0);r.check("subida moderada",r.trans.maxY<14);r.check("fade antes da arena",r.trans.escuro);r.check("fade revela arena",not game.Players.LocalPlayer.PlayerGui.TransicaoSala:FindFirstChildOfClass("Frame").Visible);return game.HttpService:JSONEncode(r.trans)'),flush=True)
    print(lua('local r=shared.G14;r.check("partida real iniciou",r.snap.combat.active);r.check("maos liberadas",next(r.snap.salaConceitual.maos)==nil);r.check("sem recusas no fluxo normal",#r.erros==0);return "Erros "..table.concat(r.erros," | ")'),flush=True)
    shot('g18_regressao_partida')
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=650,y=100)]);time.sleep(.3)
    key('T')
    print(lua('shared.G14.check("T nao abre arvore em partida",game.Players.LocalPlayer.PlayerGui:FindFirstChild("Arvores")==nil);return "arvore fora da partida"'),flush=True)
    # require de MesaState em execute_luau divergiu do estado do LocalScript real.
    # A bancada separada exige eventos e estado publicados pelo monitor do jogo.
    # Não contar estes checks como aprovados por este roteiro.
    print('M/Texto: verificacao separada obrigatoria em g18_atalhos.py',flush=True)
    key('Q')
    print(lua('shared.G14.check("Q cancela sem menu Roblox",not game:GetService("GuiService").MenuIsOpen);return "Entrada"'),flush=True)
    print(call('get_console_output'),flush=True)
    print(lua('local r=shared.G14;return "FINAL "..r.falhas.."\\n"..table.concat(r.linhas,"\\n")'),flush=True)
    assert lua('return shared.G14.falhas').strip()=='0'
finally:
    if iniciou:print(call('start_stop_play',is_start=False),flush=True);print(call('get_studio_state'),flush=True)
    c.close()

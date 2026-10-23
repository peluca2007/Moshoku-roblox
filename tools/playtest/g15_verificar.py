"""G15: dados físicos por controles reais + specs de carregar jogadores.
Não representa duas conexões: o gesto remoto usa avatar de bancada.
"""
import json, os, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
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
    call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code=k)])
    time.sleep(.5)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
def aim():
    lua('shared.G15.mirar=true;return "mira bandeja"');time.sleep(.7);key('E');lua('shared.G15.mirar=false;return "livre"');time.sleep(.4)
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if 'MoshokuRPGMesa' in s['name'])
    assert 'Mode: Edit' in call('get_studio_state'), 'Encerre o Play autorizado antes de sincronizar.'
    lua('workspace:SetAttribute("MoshokuTesteMestre",nil);return "Edit"','Edit')
    items=studio_sync.collect()
    for i in range(0,len(items),6):
        result=lua(studio_sync.chunk_code(items[i:i+6]),'Edit');assert result.startswith('alterados:'),result
    print('Fonte sincronizada',flush=True)
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
    result=lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);return p.." specs / "..f.." falhas"','Server');print(result,flush=True)
    if ' / 0 falhas' not in result: print(call('get_console_output'),flush=True);raise AssertionError(result)
    print(lua('''local r={falhas=0,linhas={},erros={}};shared.G15=r;function r.check(n,v) table.insert(r.linhas,(if v then "OK " else "FALHA ")..n);if not v then r.falhas+=1 end end;r.con=game.ReplicatedStorage.Mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.snap=d elseif k=="log" and d.tone=="erro" then table.insert(r.erros,d.text) end end);game.ReplicatedStorage.Mesa:FireServer("requestSnapshot",{});task.wait(.5);game:GetService("RunService"):BindToRenderStep("G15MiraTeste",Enum.RenderPriority.Camera.Value+5,function() local c=workspace.CurrentCamera;if r.mirar then c.CFrame=CFrame.lookAt(c.CFrame.Position,workspace.SalaRPG.VeludoDados.Position) elseif r.olhar then c.CFrame=CFrame.lookAt(c.CFrame.Position,c.CFrame.Position+Vector3.new(-1,-.15,0)) end end);r.check("lobby ativo",r.snap.salaConceitual~=nil and not r.snap.combat.active);return "Sala pronta"'''),flush=True)
    # Levanta da cadeira pelo salto real, aproxima da bandeja por fixture de posição.
    key('Space')
    print(lua('local p=game.Players:GetPlayers()[1];local h=p.Character.Humanoid;h.Sit=false;p.Character:PivotTo(CFrame.new(257,4,-6)*CFrame.Angles(0,math.pi/2,0));return "bandeja"','Server'),flush=True);time.sleep(.5)
    aim()
    print(lua('''local r=shared.G15;local p=game.Players.LocalPlayer;local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..p.UserId);r.check("pegar por E real",m and m:GetAttribute("EmMaos"));r.check("maos dados confirmadas",r.snap.salaConceitual.maos[p.UserId]=="dados-brotos" or r.snap.salaConceitual.maos[tostring(p.UserId)]=="dados-brotos");r.check("sem dialogo ao pegar",not p.PlayerGui.SalaPapelInterface.Enabled);r.check("prompt toque e controle",m and m.Dado2:FindFirstChild("MaoLobby")~=nil);local b=workspace.SalaObjetosLocais:FindFirstChild("Bracos_"..p.Name);r.check("braco alcanca dados",b and b.RightHand.Transparency<.1);return "Dados na mao"'''),flush=True)
    lua('shared.G15.olhar=true;return "olhar mesa"');time.sleep(.7);shot('g15_dados_na_mao')
    print(lua('local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..game.Players.LocalPlayer.UserId);local dentro=m~=nil;if m then for _,p in m:GetChildren() do if p:IsA("BasePart") then for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do local q,on=workspace.CurrentCamera:WorldToViewportPoint(p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2));if not on or q.Z<=0 then dentro=false end end end end end end end;shared.G15.check("trio inteiro no campo de visao",dentro);return "Enquadramento"'),flush=True)
    print(lua('local p=game.Players.LocalPlayer;local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..p.UserId);local br=workspace.SalaObjetosLocais:FindFirstChild("Bracos_"..p.Name);local originais={};if br then for _,b in br:GetChildren() do if b:IsA("BasePart") then originais[b]=b.CanQuery;b.CanQuery=true end end end;local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={p.Character};local livre=true;for i=1,3 do local d=m:FindFirstChild("Dado"..i);local v=d.Position-workspace.CurrentCamera.CFrame.Position;local hit=workspace:Raycast(workspace.CurrentCamera.CFrame.Position,v.Unit*(v.Magnitude+.01),params);if not hit or hit.Instance~=d then livre=false end end;for b,v in originais do b.CanQuery=v end;shared.G15.check("bracos nao encobrem os tres dados",livre);return "Dados legiveis"'),flush=True)
    lua('local r={max=0,dist=0};shared.G15Fisica=r;r.con=game:GetService("RunService").Heartbeat:Connect(function() local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..game.Players:GetPlayers()[1].UserId);if m and not m:GetAttribute("EmMaos") and not m:GetAttribute("Pousou") then local p=m.Dado1;r.origem=r.origem or p.Position;r.max=math.max(r.max,p.AssemblyLinearVelocity.Magnitude);r.dist=math.max(r.dist,(p.Position-r.origem).Magnitude) end end);return "Monitor de fisica"','Server')
    # Segura e solta clique: carga mede tempo, envio nunca contém valores de faces.
    xy=json.loads(lua('local v=workspace.CurrentCamera.ViewportSize;return game.HttpService:JSONEncode({math.floor(v.X/2),math.floor(v.Y/2)})'))
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='moveTo',x=xy[0],y=xy[1]),dict(action='mouseButtonDown',mouse_button='left'),dict(action='wait',wait_time_ms=350),dict(action='mouseButtonUp',mouse_button='left')]);time.sleep(.2)
    print(lua('''local p=game.Players:GetPlayers()[1];local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..p.UserId);assert(m and not m:GetAttribute("EmMaos"),"clique nao lancou");assert(not m.Dado1.Anchored,"dado nao fisico");assert(m.Dado1:GetNetworkOwner()==nil,"dono nao servidor");shared.G15Pos=m.Dado1.Position;return "Impulso nativo, dono servidor; velocidade "..tostring(m.Dado1.AssemblyLinearVelocity)''','Server'),flush=True)
    time.sleep(.4)
    print(lua('local r=shared.G15Fisica;assert(r.max>1 and r.dist>.05,"dado parado");r.con:Disconnect();return "Fisica: pico "..r.max..", deslocamento "..r.dist','Server'),flush=True)
    time.sleep(2.2)
    print(lua('local r=shared.G15;local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..game.Players.LocalPlayer.UserId);r.check("pouso confirmado",m and m:GetAttribute("Pousou"));r.check("tres faces reais",m and m.Dado1:GetAttribute("Valor") and m.Dado2:GetAttribute("Valor") and m.Dado3:GetAttribute("Valor"));return "Pousou"'),flush=True)
    print(lua('local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..game.Players.LocalPlayer.UserId);shared.G15.check("tamanho fisico restaurado",m and math.abs(m.Dado2.Size.X-.48)<.00001);return "Escala"'),flush=True)
    shot('g15_dados_pousados')
    # Rodada autoritativa aberta pelo remoto; pegar/lancar via E + Q reais.
    lua('game.ReplicatedStorage.Mesa:FireServer("salaBrotosAbrir",{});return "Brotos"');time.sleep(.5);aim();key('Q');time.sleep(2.8)
    print(lua('''local r=shared.G15;local p=game.Players.LocalPlayer;local br=r.snap.salaConceitual.brincadeiraBrotos;local a=br.dados[p.UserId] or br.dados[tostring(p.UserId)];local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..p.UserId);r.check("Brotos pela mao conclui",br.fase=="resultado");r.check("faces iguais ao Brotos",a and m and m.Dado1:GetAttribute("Valor")==a[1] and m.Dado2:GetAttribute("Valor")==a[2] and m.Dado3:GetAttribute("Valor")==a[3]);r.check("mestre preservado",r.snap.salaConceitual.mestre==p.UserId);return "Brotos confirmado"'''),flush=True)
    aim()
    print(lua('local r=shared.G15;local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..game.Players.LocalPlayer.UserId);local p=m and m.Dado2:FindFirstChild("MaoLobby");r.check("prompt na mao com B e toque",p and p.GamepadKeyCode==Enum.KeyCode.ButtonB and p.ClickablePrompt);if p then p:InputHoldBegin();p:InputHoldEnd() end;return "Prompt nativo (ButtonB fisico nao emulado pelo MCP)"'),flush=True);time.sleep(.6)
    print(lua('local r=shared.G15;local m=workspace.SalaDadosFisicos:FindFirstChild("Dados_"..game.Players.LocalPlayer.UserId);r.check("soltar pelo prompt nativo",m and not m:GetAttribute("EmMaos"));return "Prompt"'),flush=True)
    # Captura de apresentação remota: dado replicado não vira folha falsa.
    print(lua((base/'g15_bracos.luau').read_text(encoding='utf-8')),flush=True)
    lua('game.ReplicatedStorage.Mesa:FireServer("salaArrumar",{});return "arrumar"');time.sleep(.6)
    print(lua('local r=shared.G15;r.check("arrumar limpa dados",#workspace.SalaDadosFisicos:GetChildren()==0);return "Arrumado"'),flush=True)
    print(lua((base/'g15_carregar.luau').read_text(encoding='utf-8'),'Server'),flush=True);time.sleep(.4)
    print(lua('local r=shared.G15;local p=game.Players.LocalPlayer;r.check("alvo real carregado",p.Character.HumanoidRootPart:GetAttribute("CarregadoPor")==999);r.check("escape visivel no toque",p.PlayerGui.SalaSoltura.Enabled and p.PlayerGui.SalaSoltura.Soltar.Visible);return "Alvo"'),flush=True)
    key('Space')
    print(lua('local s=shared.G15Carry;local p=game.Players:GetPlayers()[1];assert(s.escaped,"salto nao enviou soltura");assert(not p.Character.HumanoidRootPart.Anchored and not p.Character.Humanoid.PlatformStand,"alvo preso");s.heart:Disconnect();s.remote:Disconnect();s.api.arrumar();s.char:Destroy();return "Salto real soltou pelo remoto"','Server'),flush=True)
    print(lua('shared.G15.check("escape recolhe interface",not game.Players.LocalPlayer.PlayerGui.SalaSoltura.Enabled);return "Solto"'),flush=True)
    print(lua(r'return table.concat(shared.G15.linhas,"\n").."\nG15: "..shared.G15.falhas.." falhas\nErros: "..table.concat(shared.G15.erros," | ")'),flush=True)
    assert lua('return tostring(shared.G15.falhas)')=='0'
    print(call('get_console_output'),flush=True)
finally:
    if iniciou:print(call('start_stop_play',is_start=False),flush=True)
    c.close()

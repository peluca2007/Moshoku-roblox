"""Pegada por mouse real, largada/arremesso e dados físicos da fonte G17."""
import json, os, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
base=Path(__file__).parent
sys.path.insert(0,str(base.parent))
os.environ['MOSHOKU_TESTE_JOGADOR']='1'
os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;iniciou=False
def call(tool,**kw):
    r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
    if r.get('isError') or 'erro' in r:raise RuntimeError(r)
    return r['text']
def lua(code,dm='Client'):return call('execute_luau',code=code,datamodel_type=dm)
def key(k):call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code=k)]);time.sleep(.45)
def mouse(down):
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonDown' if down else 'mouseButtonUp',mouse_button='left',x=503,y=260)])
    time.sleep(.55)
def aim(path):lua('shared.G17.alvo='+path+';return "mira"');time.sleep(.65)
def check(name,expr):print(lua('shared.G17.check('+json.dumps(name)+','+expr+');return '+json.dumps(name)),flush=True)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if 'MoshokuRPGMesa' in s['name'])
    assert 'Mode: Edit' in call('get_studio_state'),'Play alheio preservado'
    items=studio_sync.collect()
    for i in range(0,len(items),6):assert lua(studio_sync.chunk_code(items[i:i+6]),'Edit').startswith('alterados:')
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
    lua('game:GetService("TextChatService").ChatWindowConfiguration.Enabled=false;pcall(function() game:GetService("StarterGui"):SetCore("ChatActive",false) end);return "chat de teste fechado"')
    if "--visual" not in sys.argv:
        print(lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);assert(f==0,"specs falharam: "..f);return p.." specs / "..f.." falhas"','Server'),flush=True)
    print(lua('''local r={falhas=0,linhas={},erros={}};shared.G17=r;function r.check(n,v) table.insert(r.linhas,(if v then "OK " else "FALHA ")..n);if not v then r.falhas+=1 end end;game.ReplicatedStorage.Mesa.OnClientEvent:Connect(function(k,d) if k=="snapshot" then r.s=d elseif k=="log" and d.tone=="erro" then table.insert(r.erros,d.text) end end);game.ReplicatedStorage.Mesa:FireServer("requestSnapshot",{});function r.mao() local m=r.s.salaConceitual.maos;local id=game.Players.LocalPlayer.UserId;return m[id] or m[tostring(id)] end;game:GetService("RunService"):BindToRenderStep("G17Mira",Enum.RenderPriority.Camera.Value+5,function() if r.alvo then local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=CFrame.lookAt(c.CFrame.Position,r.alvo.Position) end end);return "monitor"'''),flush=True);time.sleep(.6)
    if "--dados" not in sys.argv:
        aim('workspace.SalaObjetosLocais.PilhaDeFichas')
        check('contorno ao mirar','workspace.SalaObjetosLocais.ContornoPegada.Enabled and workspace.SalaObjetosLocais.ContornoPegada.Adornee==workspace.SalaObjetosLocais.PilhaDeFichas')
        check('sem prompt de pegar','workspace.SalaObjetosLocais.PilhaDeFichas:FindFirstChildOfClass("ProximityPrompt")==nil')
        mouse(True)
        check('clique mantido pega ficha','shared.G17.mao()==require(game.ReplicatedStorage.Shared.PersonagensProntos)[1].id')
        check('sem botao segurar','game.Players.LocalPlayer.PlayerGui.SalaPapelInterface:FindFirstChild("SegurarPapel")==nil')
        check('dicas inferiores esquerda','game.Players.LocalPlayer.PlayerGui.SalaMaoDicas.Enabled and game.Players.LocalPlayer.PlayerGui.SalaMaoDicas.Comandos.AbsolutePosition.X<25')
        shot('g17_ficha_pegada')
        mouse(False)
        check('soltar clique larga sem impulso','shared.G17.mao()==nil and #shared.G17.s.salaConceitual.papeisSoltos==1 and shared.G17.s.salaConceitual.papeisSoltos[1].velocidade.z==0')
        time.sleep(.7);aim('workspace.SalaObjetosLocais.PilhaDeFichas');mouse(True);key('F')
        check('F arremessa com impulso','shared.G17.mao()==nil and #shared.G17.s.salaConceitual.papeisSoltos==2 and math.abs(shared.G17.s.salaConceitual.papeisSoltos[2].velocidade.z)>5')
        mouse(False);check('liberar depois de F nao duplica',' #shared.G17.s.salaConceitual.papeisSoltos==2')
        time.sleep(.7);aim('workspace.SalaObjetosLocais.PilhaDeFichas');mouse(True);key('R');mouse(False)
        check('leitura apoia consulta sem perder ficha','shared.G17.mao()~=nil and game.Players.LocalPlayer.PlayerGui.SalaPapelInterface.Enabled')
        check('sem marcadores nas maos','game.Players.LocalPlayer.PlayerGui:FindFirstChild("MarcadoresInterface")==nil')
        shot('g17_ficha_leitura');key('Q');check('Q larga leitura','shared.G17.mao()==nil')
        # Repetição rápida: início/fim reais no mesmo lote, antes de um frame de confirmação.
        aim('workspace.SalaObjetosLocais.PilhaDeFichas')
        call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonDown',mouse_button='left',x=503,y=260),dict(action='wait',wait_time_ms=20),dict(action='mouseButtonUp',mouse_button='left')]);time.sleep(.8)
        check('clique curto nao deixa objeto preso','shared.G17.mao()==nil')
        key('Space')
    print(lua('local p=game.Players:GetPlayers()[1];local h=p.Character.Humanoid;local seat=h.SeatPart;if seat then local w=seat:FindFirstChild("SeatWeld");if w then w:Destroy() end end;h.Sit=false;p.Character:PivotTo(CFrame.new(257,4,-6)*CFrame.Angles(0,math.pi/2,0));return "bandeja"','Server'),flush=True);time.sleep(.7)
    lua('workspace.CurrentCamera.CFrame=CFrame.new(257,5.5,-6);return "camera bancada"')
    aim('workspace.SalaObjetosLocais.BrotosDado2');mouse(True)
    check('dados pegos por clique mantido','shared.G17.mao()=="dados-brotos"')
    check('copia suave sem mover fisica local','workspace:FindFirstChild("SalaDadosEmMaos")~=nil and workspace.SalaDadosFisicos["Dados_"..game.Players.LocalPlayer.UserId].Dado2.LocalTransparencyModifier==1')
    check('dados com cores distintas','workspace.SalaDadosEmMaos.Dado1.Color~=workspace.SalaDadosEmMaos.Dado2.Color and workspace.SalaDadosEmMaos.Dado2.Color~=workspace.SalaDadosEmMaos.Dado3.Color')
    shot('g17_dados_mao');key('F')
    check('F libera dados fisicos e limpa copia','shared.G17.mao()==nil and workspace:FindFirstChild("SalaDadosEmMaos")==nil and not workspace.SalaDadosFisicos["Dados_"..game.Players.LocalPlayer.UserId].Dado2.Anchored')
    print(lua('local m=workspace.SalaDadosFisicos["Dados_"..game.Players:GetPlayers()[1].UserId];assert(m.Dado2:GetNetworkOwner()==nil);return "dono servidor"','Server'),flush=True)
    mouse(False);time.sleep(3)
    check('pouso suave confirma tres faces','(function() local m=workspace.SalaDadosFisicos["Dados_"..game.Players.LocalPlayer.UserId];return m:GetAttribute("Pousou") and m.Dado1:GetAttribute("Valor") and m.Dado2:GetAttribute("Valor") and m.Dado3:GetAttribute("Valor") end)()')
    shot('g17_dados_pouso')
    # Largada de dados sem impulso, distinta do F.
    aim('workspace.SalaObjetosLocais.BrotosDado2');mouse(True)
    mouse(False);check('liberar clique larga dados','shared.G17.mao()==nil')
    time.sleep(3)
    lua('game.ReplicatedStorage.Mesa:FireServer("salaBrotosAbrir",{});return "Brotos"');time.sleep(.5)
    aim('workspace.SalaObjetosLocais.BrotosDado2');mouse(True);key('F');mouse(False);time.sleep(3)
    check('Brotos real com arremesso','shared.G17.s.salaConceitual.brincadeiraBrotos.fase=="resultado"')
    check('sem erros de pedidos no fluxo',' #shared.G17.erros==0')
    print(lua('local r=shared.G17;return game.HttpService:JSONEncode({falhas=r.falhas,linhas=r.linhas,erros=r.erros})'),flush=True)
    print(call('get_console_output'),flush=True)
    assert lua('return tostring(shared.G17.falhas)')=='0'
except Exception:
    try: print(call("get_console_output"),flush=True)
    except Exception: pass
    raise
finally:
    if iniciou:
        print(call('start_stop_play',is_start=False),flush=True);print(call('get_studio_state'),flush=True)
    c.close()

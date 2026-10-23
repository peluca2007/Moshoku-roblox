"""UI real com estado injetado e emulador de dispositivo; não aparelho físico."""
import json, os, re, shutil, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8');base=Path(__file__).parent
sys.path.insert(0,str(base.parent));os.environ['MOSHOKU_TESTE_JOGADOR']='1';os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;iniciou=False;original=None;orientacao=None
def call(tool,**kw):
    r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
    if r.get('isError') or 'erro' in r: raise RuntimeError(r)
    return r['text']
def lua(code,dm='Client'): return call('execute_luau',code=code,datamodel_type=dm)
def key(k):
    call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code=k)]);time.sleep(.4)
def click(x,y):
    call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=round(x),y=round(y))]);time.sleep(.5)
def election(name):
    pos=json.loads(lua('local b=shared.G16UI.gui.Eleicao.Opcoes.'+name+';local sc=b.Parent;sc.CanvasPosition=Vector2.new(0,math.max(0,b.AbsolutePosition.Y-sc.AbsolutePosition.Y+sc.CanvasPosition.Y-sc.AbsoluteSize.Y+b.AbsoluteSize.Y+10));task.wait(.2);local a=b.AbsolutePosition+b.AbsoluteSize/2;return game.HttpService:JSONEncode({a.X,a.Y})'))
    click(*pos)
def paper(name):
    pos=json.loads(lua('local g=shared.G16UI.pages.gui;local sc=g.Pagina;local b=sc:FindFirstChild("'+name+'") or g:FindFirstChild("'+name+'");local y=b.AbsolutePosition.Y-sc.AbsolutePosition.Y;if y<0 then sc.CanvasPosition+=Vector2.new(0,y) elseif y+b.AbsoluteSize.Y>sc.AbsoluteSize.Y then sc.CanvasPosition+=Vector2.new(0,y+b.AbsoluteSize.Y-sc.AbsoluteSize.Y) end;task.wait(.2);local a=b.AbsolutePosition+b.AbsoluteSize/2;local p=g.Adornee;local w=p.CFrame:PointToWorldSpace(Vector3.new(-(a.X/g.CanvasSize.X-.5)*p.Size.X,(.5-a.Y/g.CanvasSize.Y)*p.Size.Y,-p.Size.Z/2-.002));local q=workspace.CurrentCamera:WorldToViewportPoint(w);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y})'))
    click(*pos)
def shot(name):
    m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
    if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if 'MoshokuRPGMesa' in s['name'])
    assert 'Mode: Edit' in call('get_studio_state'),'Play alheio preservado'
    for i in range(0,len(items:=studio_sync.collect()),6): assert lua(studio_sync.chunk_code(items[i:i+6]),'Edit').startswith('alterados:')
    original=lua('return game:GetService("StudioDeviceSimulatorService"):GetDeviceAsync()','Edit')
    orientacao=lua('return game:GetService("StudioDeviceSimulatorService"):GetOrientationAsync().Name','Edit')
    print(lua('game:GetService("StudioDeviceSimulatorService"):SetDeviceAsync("iphone_7");game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.Portrait);return "emulador iPhone7"','Edit'),flush=True)
    print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
    result=lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);return p.." specs / "..f.." falhas"','Server');print(result,flush=True);assert ' / 0 falhas' in result
    lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.Portrait;game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.Portrait);return "retrato real no emulador"');time.sleep(1)
    print(lua((base/'g16_ui.luau').read_text(encoding='utf-8')),flush=True);time.sleep(.6)
    print(lua('local r=shared.G16UI;local f=r.gui.Eleicao;local v=workspace.CurrentCamera.ViewportSize;local a,b=f.AbsolutePosition,f.AbsoluteSize;r.check("emulador em retrato",v.X<v.Y);r.check("convite cabe em retrato",a.X>=0 and a.X+b.X<=v.X and a.Y+b.Y<=v.Y);r.check("convite congela enquanto aberto",r.eleicao.congelar());return tostring(v)'),flush=True);shot('g16_convite_retrato')
    election('Recusar')
    print(lua('local r=shared.G16UI;r.check("recusar por clique recolhe",not r.eleicao.congelar());local d=r.envios[#r.envios];r.check("recusa envia escolha falsa",d and d.cmd=="salaCandidatar" and d.d.sim==false);r.e.fim=nil;r.eleicao.atualizar(r.e,true);r.check("prazo vazio nao prende novamente",not r.eleicao.congelar());r.eleicao.abrir();r.check("pode reconsiderar sem reconectar",r.eleicao.congelar());return "recusa"'),flush=True)
    election('Aceitar')
    print(lua('local r=shared.G16UI;local d=r.envios[#r.envios];r.check("aceitar por clique",d.cmd=="salaCandidatar" and d.d.sim==true);r.convite("rolagem");return "rolagem"'),flush=True)
    election('VoltarMesa')
    print(lua('local r=shared.G16UI;r.check("mesa libera para dados fisicos",not r.eleicao.congelar());r.eleicao.abrir();return "reabrir"'),flush=True)
    election('RolarBrotos')
    print(lua('local r=shared.G16UI;local d=r.envios[#r.envios];r.check("rolar por clique",d.cmd=="salaRolar");r.e.dados[game.Players.LocalPlayer.UserId]={1,2,3};r.eleicao.atualizar(r.e,true);r.check("resultado proprio recolhe convite",not r.eleicao.congelar());return "dados"'),flush=True)
    print(lua('local r=shared.G16UI;r.pages.abrir("ficha","mago-de-fogo");r.pages.fechar();local d=r.envios[#r.envios];r.check("fechar antes do ack cancela pega pendente",not r.pages.aberto() and d.cmd=="salaPapel" and d.d.id==false);return "pega rapida"'),flush=True)
    lua('local r=shared.G16UI;r.sala.maos[game.Players.LocalPlayer.UserId]="mago-de-fogo";r.update();r.pages.abrir("ficha","mago-de-fogo",nil,true);return "troca rapida"')
    key('X')
    print(lua('local r=shared.G16UI;local troca=r.envios[#r.envios];r.check("troca envia outra ficha",troca.d.id~="mago-de-fogo");r.pages.fechar();local d=r.envios[#r.envios];r.check("fechar troca antes do ack cancela sem reabrir antiga",not r.pages.aberto() and d.d.id==false);r.sala.maos[game.Players.LocalPlayer.UserId]=nil;r.update();return "troca cancelada"'),flush=True)
    print(lua('local r=shared.G16UI;r.sala.maos[game.Players.LocalPlayer.UserId]="livro-ajustes";r.update();r.pages.abrir("placar");local n=#r.envios;r.pages.fechar();r.check("fechar consulta retoma livro sem nova pega",r.pages.aberto() and r.pages.part.Size.Z>.2 and #r.envios==n);r.pages.fechar(false);r.sala.maos[game.Players.LocalPlayer.UserId]=nil;r.update();return "livro preservado"'),flush=True)
    # Fecha consulta com ficha recebida: não envia id=false nem nova aquisição.
    print(lua('local r=shared.G16UI;r.pages.abrir("ajustes");r.sala.maos[game.Players.LocalPlayer.UserId]="mago-de-fogo";r.update();r.antes=#r.envios;return "consulta recebendo"'),flush=True);time.sleep(.5)
    paper('GuardarPapel')
    print(lua('local r=shared.G16UI;r.check("guardar consulta retoma ficha recebida",r.pages.aberto() and r.pages.gui.SegurarPapel.Visible);r.check("consulta nao descarta nem repede posse",#r.envios==r.antes);return "ficha preservada"'),flush=True)
    key('T')
    print(lua('local r=shared.G16UI;r.check("entregar abre lista",r.pages.gui.Pagina:FindFirstChild("Entregar_999")~=nil);return "lista"'),flush=True);time.sleep(.5)
    paper('Entregar_999')
    print(lua('local r=shared.G16UI;r.check("aguarda confirmacao com papel aberto",r.pages.aberto() and not r.pages.gui.Pagina.Entregar_999.Interactable);r.recusar();r.check("recusa mantem papel e reabilita",r.pages.aberto() and r.pages.gui.Pagina.Entregar_999.Interactable);return "recusa preservada"'),flush=True)
    paper('Entregar_999')
    print(lua('local r=shared.G16UI;r.sala.maos[game.Players.LocalPlayer.UserId]=nil;r.sala.maos[999]="mago-de-fogo";r.update();r.check("confirmacao fecha somente remetente",not r.pages.aberto());r.sala.maos[game.Players.LocalPlayer.UserId]="mago-de-fogo";r.pages.abrir("ficha","mago-de-fogo",nil,true);return "confirmado"'),flush=True)
    key('T')
    print(lua('local r=shared.G16UI;r.check("alvo ocupado identificado e desabilitado",not r.pages.gui.Pagina.Entregar_999.Interactable and r.pages.gui.Pagina.Entregar_999.Text:find("ocupadas",1,true)~=nil);r.pages.fechar(false);r.convite();return "ocupado"'),flush=True)
    lua('local r=shared.G16UI;r.eleicao.atualizar(nil,true);r.pages.abrir("mestre");r.pages.gui.Pagina.Modo_luta.Text=string.rep("Descrição longa de uma opção ",7);return "preparacao"');time.sleep(.7)
    print(lua('local r=shared.G16UI;local b=r.pages.gui.Pagina.Modo_luta;r.check("opcoes longas cabem sem cortar",b.TextFits and b.TextBounds.Y+16<=b.AbsoluteSize.Y+.1);r.check("alvo de clique preserva altura",b.AbsoluteSize.Y>=54);return "texto legivel"'),flush=True);shot('g16_preparacao_retrato')
    lua('shared.G16UI.pages.fechar(false);shared.G16UI.convite();return "convite"')
    print(lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeLeft;game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft);return "paisagem"'),flush=True);time.sleep(1)
    print(lua('local r=shared.G16UI;local f=r.gui.Eleicao;local v=workspace.CurrentCamera.ViewportSize;local a,b=f.AbsolutePosition,f.AbsoluteSize;r.check("convite cabe em paisagem baixa",a.X>=0 and a.X+b.X<=v.X and a.Y+b.Y<=v.Y);r.check("opcoes rolaveis",f.Opcoes.ScrollingEnabled and f.Opcoes.AutomaticCanvasSize==Enum.AutomaticSize.Y);return tostring(v)'),flush=True);shot('g16_convite_paisagem')
    print(lua('local r=shared.G16UI;return game.HttpService:JSONEncode({falhas=r.falhas,linhas=r.linhas})'),flush=True);assert lua('return tostring(shared.G16UI.falhas)')=='0'
    print(call('get_console_output'),flush=True)
finally:
    try:
        if iniciou:print(call('start_stop_play',is_start=False),flush=True)
    finally:
        try:
            if original is not None:
                restore='local s=game:GetService("StudioDeviceSimulatorService");s:StopSimulationAsync();'
                if original!='default':restore+='s:SetDeviceAsync('+json.dumps(original)+');s:SetOrientationAsync(Enum.ScreenOrientation['+json.dumps(orientacao)+']);'
                print(lua(restore+'return s:GetDeviceAsync()','Edit'),flush=True)
        finally:c.close()

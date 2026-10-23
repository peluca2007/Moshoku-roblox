"""Consultas físicas: cliques nativos, emulador e foco lógico. Sem aparelhos físicos."""
import json,os,re,shutil,sys,time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8');base=Path(__file__).parent
sys.path.insert(0,str(base.parent));os.environ['MOSHOKU_TESTE_JOGADOR']='1';os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;iniciou=False;original=None;orientacao=None
def call(tool,**kw):
 r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
 if r.get('isError') or 'erro' in r:raise RuntimeError(r)
 return r['text']
def lua(code,dm='Client'):return call('execute_luau',code=code,datamodel_type=dm)
def key(k):
 call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code=k)]);time.sleep(.5)
def paper(name):
 pos=json.loads(lua('local g=shared.G18.pages.gui;local sc=g.Pagina;local b=g:FindFirstChild("'+name+'",true);assert(b,"botao ausente");local y=b.AbsolutePosition.Y-sc.AbsolutePosition.Y;if b:IsDescendantOf(sc) then if y<0 then sc.CanvasPosition+=Vector2.new(0,y) elseif y+b.AbsoluteSize.Y>sc.AbsoluteSize.Y then sc.CanvasPosition+=Vector2.new(0,y+b.AbsoluteSize.Y-sc.AbsoluteSize.Y) end end;task.wait(.2);local c=workspace.CurrentCamera;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=shared.G18.cf;shared.G18.pages.posicionar(c,0);local a=b.AbsolutePosition+b.AbsoluteSize/2;local p=g.Adornee;local w=p.CFrame:PointToWorldSpace(Vector3.new(-(a.X/g.CanvasSize.X-.5)*p.Size.X,(.5-a.Y/g.CanvasSize.Y)*p.Size.Y,-p.Size.Z/2-.002));local q=workspace.CurrentCamera:WorldToViewportPoint(w);return game.HttpService:JSONEncode({q.X,q.Y-game:GetService("GuiService"):GetGuiInset().Y,g.AbsolutePosition.Y,b.AbsolutePosition.Y,b.AbsoluteSize.Y,g.CanvasSize.Y,q.Y})'))
 call('user_mouse_input',datamodel_type='Client',actions=[dict(action='mouseButtonClick',mouse_button='left',x=round(pos[0]),y=round(pos[1]))]);time.sleep(.5)
 print('CLICK',name,pos,flush=True)
def shot(name):
 m=re.search(r'\[imagem salva em (.*?)\]',call('screen_capture',capture_id=name))
 if m:shutil.copyfile(m[1],base/(name+Path(m[1]).suffix))
try:
 sid=next(s['id'] for s in json.loads(c.call('list_roblox_studios',{})['text'])['studios'] if 'MoshokuRPGMesa' in s['name'])
 assert 'Mode: Edit' in call('get_studio_state'),'Play alheio preservado'
 items=studio_sync.collect()
 for i in range(0,len(items),6):assert lua(studio_sync.chunk_code(items[i:i+6]),'Edit').startswith('alterados:')
 original=lua('return game:GetService("StudioDeviceSimulatorService"):GetDeviceAsync()','Edit');orientacao=lua('return game:GetService("StudioDeviceSimulatorService"):GetOrientationAsync().Name','Edit')
 lua('game:GetService("StudioDeviceSimulatorService"):SetDeviceAsync("iphone_7");game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.Portrait);return "iPhone7"','Edit')
 print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
 print(lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.Portrait;game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.Portrait);game.TextChatService.ChatWindowConfiguration.Enabled=false;return "retrato"'),flush=True)
 key('C')
 print(lua('local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;assert(not game.GuiService.TouchControlsEnabled,"consulta de producao suspende controles");g.Enabled=false;g.Adornee.Transparency=1;g.Adornee.CanQuery=false;return "consulta real aberta; desenho oculto somente para nao sobrepor bancada"'),flush=True)
 print(lua((base/'g18_ui.luau').read_text(encoding='utf-8')),flush=True);time.sleep(1)
 print(lua('local r=shared.G18;r.check("emulador retrato",workspace.CurrentCamera.ViewportSize.X<workspace.CurrentCamera.ViewportSize.Y);return r.medidas("retrato")'),flush=True);shot('g18_consulta_retrato')
 # O próprio assento da mesa, sem adulterar a função de contexto do cliente.
 print(lua('local p=game.Players:GetPlayers()[1];local h=p.Character:FindFirstChildOfClass("Humanoid");local seat;for _,s in workspace.SalaRPG:GetDescendants() do if s:IsA("Seat") and s:GetAttribute("LugarSala")~=nil then seat=s;break end end;assert(seat);seat:Sit(h);return seat.Name','Server'),flush=True);time.sleep(1)
 print(lua('local r=shared.G18;local g=r.pages.gui;r.check("sentar atualiza sem snapshot",g.Pagina.LancarDados.Interactable);r.n=#r.envios;return "sentado"'),flush=True)
 paper('Modo_luta');paper('Nivel_1')
 print(lua('local r=shared.G18;r.check("modo/nivel atuais nao enviam nem apagam pronto",#r.envios==r.n and r.sala.monstros and r.sala.pessoas[2].pronto);return "opcoes atuais"'),flush=True)
 paper('Modo_duelo')
 print(lua('local r=shared.G18;local e=r.envios[#r.envios];r.check("modo diferente envia uma intencao",#r.envios==r.n+1 and e and e.cmd=="salaConfigurar" and e.d.modo=="duelo");return game.HttpService:JSONEncode({envios=r.envios,clicados=r.clicados,antes=r.n,input=tostring(game.UserInputService:GetLastInputType()),scroll=tostring(r.pages.gui.Pagina.CanvasPosition)})'),flush=True);shot('g18_troca_modo')
 if '--debug' in sys.argv:
  print(lua('local r=shared.G18;local a={};for _,o in game.Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(183,356) do table.insert(a,o:GetFullName()) end;return game.HttpService:JSONEncode({sobre=a,touch=game.GuiService.TouchControlsEnabled})'),flush=True)
  print(lua('game.GuiService.TouchControlsEnabled=false;return "controles suspensos apenas nesta bancada"'),flush=True)
  paper('Modo_duelo')
  print(lua('return game.HttpService:JSONEncode({envios=shared.G18.envios,clicados=shared.G18.clicados})'),flush=True)
  raise SystemExit(0)
 paper('Aba_pessoas');paper('Transferir_999')
 print(lua('local r=shared.G18;r.sala.pessoas[2].nome="Amigo atualizado";r.update();task.wait(.2);r.check("confirmacao sobrevive snapshot",r.pages.gui.Pagina.Transferir_999.Text:find("Confirmar",1,true)~=nil);return "confirmacao preservada"'),flush=True)
 paper('Transferir_999')
 print(lua('local r=shared.G18;local e=r.envios[#r.envios];r.check("segundo clique transfere",e.cmd=="salaTransferir" and e.d.userId==999);return "transferir"'),flush=True)
 paper('Transferir_999');time.sleep(5.2)
 print(lua('local r=shared.G18;r.check("confirmacao expira visivelmente",r.pages.gui.Pagina.Transferir_999.Text=="Passar o posto de mestre");return "expirou"'),flush=True)
 paper('Aba_sessao')
 print(lua('local r=shared.G18;r.gamepad=true;game.GuiService.SelectedObject=nil;r.pages.abrir("mestre");return "entrou pelo controlador real com tipo Gamepad1 injetado"'),flush=True);time.sleep(.8)
 print(lua('local r=shared.G18;local g=r.pages.gui;local sc=g.Pagina;r.check("entrada automatica do controlador",game.GuiService.SelectedObject==sc.Abas.Aba_sessao);local alvo=sc.Monstros;sc.CanvasPosition+=Vector2.new(0,math.max(0,alvo.AbsolutePosition.Y+alvo.AbsoluteSize.Y-sc.AbsolutePosition.Y-sc.AbsoluteSize.Y));task.wait(.3);game.GuiService.SelectedObject=sc.Monstros;task.wait(.3);r.check("foco inicial em alvo visivel",game.GuiService.SelectedObject==sc.Monstros);r.sala.pessoas[2].pronto=false;r.update();task.wait(.4);local b=game.GuiService.SelectedObject;r.check("foco restaurado pelo nome",b and b.Name=="Monstros" and b.Parent==sc);r.check("foco rola para ficar visivel",b and b.AbsolutePosition.Y>=sc.AbsolutePosition.Y-1 and b.AbsolutePosition.Y+b.AbsoluteSize.Y<=sc.AbsolutePosition.Y+sc.AbsoluteSize.Y+1);r.gamepad=false;return "foco"'),flush=True)
 print(lua('local p=game.Players:GetPlayers()[1];local h=p.Character:FindFirstChildOfClass("Humanoid");h.Sit=false;p.Character:PivotTo(CFrame.new(250,5,-16));return "levantou"','Server'),flush=True);time.sleep(1)
 print(lua('local r=shared.G18;local g=r.pages.gui;r.check("levantar bloqueia configuracao sem snapshot",not g.Pagina.Modo_luta.Interactable and not g.Pagina.LancarDados.Interactable and g.Pagina.LancarDados.Text:find("Sente",1,true)~=nil);game.GuiService.SelectedObject=nil;g.Pagina.CanvasPosition=Vector2.zero;return "contexto em pe"'),flush=True)
 print(lua('game.Players.LocalPlayer.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeLeft;game:GetService("StudioDeviceSimulatorService"):SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft);return "paisagem"'),flush=True);time.sleep(1)
 print(lua('return shared.G18.medidas("paisagem")'),flush=True);shot('g18_consulta_paisagem')
 paper('GuardarPapel')
 print(lua('local r=shared.G18;r.check("fechar por toque sem Esc Tab",not r.pages.aberto());return game.HttpService:JSONEncode({falhas=r.falhas,linhas=r.linhas})'),flush=True)
 print(lua('local r=shared.G18;r.sala.maos[game.Players.LocalPlayer.UserId]="mago-de-fogo";for i=1,4 do table.insert(r.sala.pessoas,{id=990+i,nome="Destinatario "..i,admitido=true,pronto=false,equipe=0}) end;r.update();r.pages.abrir("ficha","mago-de-fogo",nil,true);r.pages.acao("Entregar");return "consulta de entrega"'),flush=True);time.sleep(.6)
 print(lua('local r=shared.G18;local sc=r.pages.gui.Pagina;sc.CanvasPosition=Vector2.new(0,1000);task.wait(.2);r.check("entrega usa consulta com rolagem efetiva",r.pages.gui.CanvasSize~=Vector2.new(650,900) and sc.CanvasPosition.Y>0);return "densidade entrega"'),flush=True)
 paper('VoltarFicha')
 print(lua('local r=shared.G18;r.check("voltar entrega restaura impressao fisica",r.pages.gui.CanvasSize==Vector2.new(650,900) and r.pages.gui.Pagina.CanvasPosition==Vector2.zero and r.pages.papel()~=nil and not r.pages.gui.GuardarPapel.Visible);r.pages.fechar(false);return "ficha restaurada"'),flush=True)
 key('Q')
 print(lua('local r=shared.G18;r.check("fechar consulta real restaura controles",game.GuiService.TouchControlsEnabled);game.GuiService.TouchControlsEnabled=false;return "restaurou true"'),flush=True)
 key('C');key('Q')
 print(lua('local r=shared.G18;r.check("valor original false preservado",not game.GuiService.TouchControlsEnabled);game.GuiService.TouchControlsEnabled=true;return "restaurou false"'),flush=True)
 print(lua('local r=shared.G18;return game.HttpService:JSONEncode({falhas=r.falhas,linhas=r.linhas})'),flush=True)
 result=json.loads(lua('return game.HttpService:JSONEncode({falhas=shared.G18.falhas})'));assert result['falhas']==0,result
 result=lua('local r=game.ServerScriptService.Server;local p,f=require(r.TestRunner).run(r.tests);assert(f==0);return p.." specs / "..f.." falhas"','Server');print(result,flush=True)
except Exception:
 try:print(call('get_console_output'),flush=True)
 except Exception:pass
 raise
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

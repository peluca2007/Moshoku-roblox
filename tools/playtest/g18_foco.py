"""Diagnóstico da seleção na consulta de produção, sem outra SurfaceGui sobreposta."""
import json,os,sys,time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8');sys.path.insert(0,str(Path(__file__).resolve().parents[1]));os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local';os.environ['MOSHOKU_TESTE_JOGADOR']='1'
from studio_mcp import Client
c=Client();sid=None;iniciou=False
def call(n,**kw):
 r=c.call(n,dict(studio_id=sid,**kw),timeout=60)
 if r.get('isError'):raise RuntimeError(r)
 return r['text']
def lua(s,dm='Client'):return call('execute_luau',code=s,datamodel_type=dm)
try:
 sid=next(s['id'] for s in json.loads(c.call('list_roblox_studios',{})['text'])['studios'] if 'MoshokuRPGMesa' in s['name'])
 assert 'Mode: Edit' in call('get_studio_state')
 print(call('start_stop_play',is_start=True),flush=True);iniciou=True;time.sleep(9)
 lua('game.TextChatService.ChatWindowConfiguration.Enabled=false;return "chat teste"')
 print(lua('local h=game.Players:GetPlayers()[1].Character.Humanoid;for _,s in workspace.SalaRPG:GetDescendants() do if s:IsA("Seat") and s:GetAttribute("LugarSala") then s:Sit(h);return s.Name end end','Server'),flush=True);time.sleep(.6)
 call('user_keyboard_input',datamodel_type='Client',actions=[dict(action='keyPress',key_code='C')]);time.sleep(.8)
 print(lua('task.delay(.2,function() local g=game.Players.LocalPlayer.PlayerGui.SalaPapelInterface;local sc=g.Pagina;local r={};shared.G18Foco=r;sc.CanvasPosition=Vector2.zero;task.wait(.3);game.GuiService.SelectedObject=g.GuardarPapel;task.wait(.15);r.ancora=game.GuiService.SelectedObject==g.GuardarPapel;game.GuiService.SelectedObject=sc.Abas.Aba_sessao;task.wait(.3);r.entrada=game.GuiService.SelectedObject==sc.Abas.Aba_sessao;local a=sc.Monstros;sc.CanvasPosition+=Vector2.new(0,math.max(0,a.AbsolutePosition.Y+a.AbsoluteSize.Y-sc.AbsolutePosition.Y-sc.AbsoluteSize.Y));task.wait(.3);game.GuiService.SelectedObject=sc.Monstros;task.wait(.3);r.selecionado=game.GuiService.SelectedObject==sc.Monstros;game.ReplicatedStorage.Mesa:FireServer("salaConfigurar",{modo="luta",nivel=1,monstros=true});task.wait(.7);local b=game.GuiService.SelectedObject;r.snapshot=b and b.Name=="Monstros" and b.Parent==sc or false;r.fim=true end);return "selecao agendada fora do comando MCP"'),flush=True)
 time.sleep(2.6)
 r=json.loads(lua('return game.HttpService:JSONEncode(shared.G18Foco)'));print(r,flush=True);assert r.get('entrada') and r.get('selecionado') and r.get('snapshot') and r.get('fim'),r
 print(call('get_console_output'),flush=True)
finally:
 if iniciou:print(call('start_stop_play',is_start=False),flush=True)
 c.close()

"""Duas conexões reais pela API oficial; fixtures nunca entram no place gerado."""
import json, os, sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
base=Path(__file__).parent
sys.path.insert(0,str(base.parent))
os.environ['MOSHOKU_TESTE_JOGADOR']='1'
os.environ['LOCALAPPDATA']='C:/Users/pedro/AppData/Local'
from studio_mcp import Client
import studio_sync
c=Client();sid=None;injetado=False
def call(tool,**kw):
    r=c.call(tool,dict(studio_id=sid,**kw),timeout=60)
    if r.get('isError') or 'erro' in r: raise RuntimeError(r)
    return r['text']
def lua(code,dm='Edit'): return call('execute_luau',code=code,datamodel_type=dm)
try:
    studios=json.loads(c.call('list_roblox_studios',{})['text'])['studios'];sid=next(s['id'] for s in studios if 'MoshokuRPGMesa' in s['name'])
    assert 'Mode: Edit' in call('get_studio_state'),'Play alheio preservado'
    items=studio_sync.collect()
    for i in range(0,len(items),6): assert lua(studio_sync.chunk_code(items[i:i+6])).startswith('alterados:')
    lua('workspace:SetAttribute("MoshokuTesteMestre",nil);return "Edit"')
    for name,cls,parent,path in [('G16TesteServidor','Script','game.ServerScriptService','g16_multi_servidor.luau'),('G16TesteCliente','LocalScript','game.StarterPlayer.StarterPlayerScripts','g16_multi_cliente.luau')]:
        source=(base/path).read_text(encoding='utf-8')
        assert ']====]' not in source
        print(lua(f'assert(not {parent}:FindFirstChild("{name}"),"fixture já existe");local s=Instance.new("{cls}");s.Name="{name}";s.Source=[====[{source}]====];s.Parent={parent};return s.Name'),flush=True)
        injetado=True
    print(lua('workspace:SetAttribute("G16Resultado",nil);task.spawn(function() local ok,r=pcall(function() return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2,"MoshokuG16") end);workspace:SetAttribute("G16Resultado",game:GetService("HttpService"):JSONEncode({chamou=ok,resultado=r}));end);return "teste solicitado"'),flush=True)
    limit=time.monotonic()+190
    while time.monotonic()<limit:
        time.sleep(8)
        try:
            result=lua('return workspace:GetAttribute("G16Resultado") or "aguardando"')
        except Exception as err:
            print('MCP aguardando retorno a Edit:',str(err)[:180],flush=True);continue
        if result!='aguardando':
            print(result,flush=True);parsed=json.loads(result);assert parsed['chamou'] and parsed['resultado']['ok'],result;break
    else: raise TimeoutError('Rodada não retornou resultado; preservar janela para diagnóstico.')
finally:
    if injetado:
        try:
            if 'Mode: Edit' in call('get_studio_state'):
                print(lua('for _,p in {game.ServerScriptService,game.StarterPlayer.StarterPlayerScripts} do for _,s in p:GetChildren() do if s.Name=="G16TesteServidor" or s.Name=="G16TesteCliente" then s:Destroy() end end end;workspace:SetAttribute("G16Resultado",nil);return "fixtures removidas de Edit"'),flush=True)
        except Exception as err: print('Limpeza pendente:',str(err)[:200],flush=True)
    c.close()

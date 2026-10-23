"""T29: DataStore real isolado, recuperação com servidor novo e limpeza.
Studio deve estar em Edit. Nunca usa scope padrão nem força sobrescrita.
"""
import json
import os
import sys
import time
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from studio_mcp import Client
from studio_sync import chunk_code, long_string

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def main():
    sys.stdout.reconfigure(encoding="utf-8")
    client = Client()
    scope = "test_" + uuid.uuid4().hex
    studio, started, configured, checked = None, False, False, False
    cleanup_errors = []

    def call(tool, **args):
        result = client.call(tool, {"studio_id": studio, **args}, timeout=150)
        if result.get("isError") or "erro" in result:
            raise RuntimeError(str(result))
        return result["text"]

    def luau(code, model="Server"):
        return call("execute_luau", datamodel_type=model, code=code)

    def start():
        nonlocal started
        assert "Current Studio Mode: Edit" in call("get_studio_state"), "Play existente preservado"
        started = True
        call("start_stop_play", is_start=True)
        time.sleep(8)

    def stop():
        nonlocal started
        print(call("start_stop_play", is_start=False), flush=True)
        started = False

    try:
        client.studio_id()
        studios = json.loads(client.call("list_roblox_studios", {})["text"])["studios"]
        matches = [s for s in studios if "MoshokuRPGMesa" in s["name"]]
        assert len(matches) == 1, "Esperava uma sessão MoshokuRPGMesa"
        studio = matches[0]["id"]
        assert "Current Studio Mode: Edit" in call("get_studio_state"), "Play existente preservado"
        print(luau("assert(not game.ServerStorage:FindFirstChild('MesaTestConfig'),'Outro teste possui o scope');return 'scope livre'", "Edit"), flush=True)
        target = (["ServerScriptService", "Server"], "MesaPersistence", "ModuleScript", os.path.join(ROOT, "src", "server", "MesaPersistence.luau"))
        print(luau(chunk_code([target]), "Edit"), flush=True)
        configured = True
        print(luau("local c=Instance.new('Folder');c.Name='MesaTestConfig';c:SetAttribute('Scope'," + long_string(scope) + ");c.Parent=game.ServerStorage; return 'scope de teste configurado'", "Edit"), flush=True)
        print("SCOPE " + scope, flush=True)
        start()
        print(luau("""
local P=require(game.ServerScriptService.Server.MesaPersistence)
local expected=""" + long_string(scope) + """
local config=game.ServerStorage:FindFirstChild(P.TEST_CONFIG_NAME)
assert(config and config:GetAttribute('Scope')==expected,'scope divergente')
local p=P.new()
assert(p.scope==expected and p.store,p.reason or 'scope incorreto')
local record,err=p:load(1)
assert(not err,err)
assert(record==nil,'scope não vazio: preservar conteúdo')
config:SetAttribute('Scope','invalido')
local bad=P.new()
config:SetAttribute('Scope',expected)
assert(bad.store==nil,'scope inválido caiu no armazenamento padrão')
return 'OK acesso real disponível, scope vazio e proteção contra scope inválido'
"""), flush=True)
        checked = True
        with open(os.path.join(ROOT, "tools", "fixtures", "ficha-v2-aria.json"), encoding="utf-8") as handle:
            fixture = handle.read().strip()
        with open(os.path.join(ROOT, "tools", "playtest", "campanha_v2.luau"), encoding="utf-8") as handle:
            template = handle.read()
        for resume in (False, True):
            if resume:
                stop()
                start()
                print("INFO recuperação em novo servidor Play", flush=True)
            code = template.replace("FIXTURE_JSON", long_string(fixture)).replace("RESUME_ONLY", "true" if resume else "false")
            result = luau(code, "Client")
            print(result, flush=True)
            assert "RESULTADO: campanha v2 ok" in result, result
            print(luau("""
local d=game.ServerStorage.MesaDebug
local p=game.Players:GetPlayers()[1]
local mine=d:Invoke('snapshotOf',p)
local token=mine.tokens[1]
assert(token,'ficha ausente')
local other=d:Invoke('snapshotAs',888888887)
assert(#other.tokens==0,'névoa revelou ficha a outro observador')
assert(d:Invoke('commandAs',888888887,'fichaDetalhe',{id=token.id})~=nil,'detalhe vazou')
local owner=d:Invoke('snapshotAs',p.UserId)
assert(#owner.tokens==1 and owner.tokens[1].pv==17,'dono perdeu acesso na névoa')
return 'OK permissões após recuperação (observadores simulados, não dois clientes)'
"""), flush=True)
        print(call("get_console_output"), flush=True)
        print("RESULTADO: salvamento, carregamento e recuperação em novo servidor aprovados", flush=True)
    finally:
        if started:
            try:
                stop()
            except Exception as exc:
                cleanup_errors.append("parar Play: " + str(exc))
        # Outro Play vazio não tem revisão-base nem autosave; assim o fechamento
        # não recria o registro removido. Só a chave do scope aleatório é removida.
        if checked and not started:
            try:
                start()
                print(luau("""
local P=require(game.ServerScriptService.Server.MesaPersistence)
local expected=""" + long_string(scope) + """
local config=game.ServerStorage:FindFirstChild(P.TEST_CONFIG_NAME)
assert(config and config:GetAttribute('Scope')==expected,'não remover: scope divergente')
local p=P.new()
assert(p.scope==expected and p.store,'não remover: store incorreto')
local d=game.ServerStorage.MesaDebug
local snapshot=d:Invoke('snapshotOf',game.Players:GetPlayers()[1])
assert(#snapshot.tokens==0 and snapshot.campaign.slot==nil,'não remover: sessão possui campanha')
p.store:RemoveAsync('slot_1')
local record,err=p:load(1)
assert(not err and record==nil,err or 'registro ainda presente')
return 'OK registro de teste removido e ausência confirmada'
"""), flush=True)
            except Exception as exc:
                cleanup_errors.append("limpar scope " + scope + ": " + str(exc))
            finally:
                if started:
                    try:
                        stop()
                    except Exception as exc:
                        cleanup_errors.append("parar limpeza: " + str(exc))
        if configured and not started:
            try:
                print(luau("local c=game.ServerStorage:FindFirstChild('MesaTestConfig');assert(c and c:GetAttribute('Scope')==" + long_string(scope) + ",'scope foi alterado');c:Destroy();return 'OK configuração removida do Edit'", "Edit"), flush=True)
            except Exception as exc:
                cleanup_errors.append("restaurar atributo: " + str(exc))
        client.close()
        if cleanup_errors:
            raise RuntimeError("; ".join(cleanup_errors))

if __name__ == "__main__":
    main()

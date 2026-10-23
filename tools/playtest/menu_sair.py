"""Cliques reais: entra no Treino, reabre MENU durante snapshots e sai.
Por segurança, exige a janela cujo nome contém Moshoku-Prototipo.rbxlx.
Uso: python tools/playtest/menu_sair.py [--studio-name Moshoku-Prototipo.rbxlx]
     python tools/playtest/menu_sair.py --list-studios"""
import argparse, json, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client
sys.stdout.reconfigure(encoding="utf-8")

PG = "LocalPlayer.PlayerGui.InicioJogo.MenuInicial.Conteudo."


def selecionar_studio(c, nome):
    resultado = c.call("list_roblox_studios", {})
    if resultado.get("isError"):
        raise RuntimeError(resultado.get("text", "Falha ao listar instâncias Studio."))
    studios = json.loads(resultado["text"]).get("studios", [])
    if nome is None:
        for studio in studios:
            print(f"{studio['name']} [{studio['id']}]")
        return None
    correspondentes = [s for s in studios if nome.casefold() in s["name"].casefold()]
    if len(correspondentes) != 1:
        nomes = ", ".join(s["name"] for s in studios) or "nenhuma instância conectada"
        raise RuntimeError(
            f"Esperava uma instância contendo {nome!r}; encontrei {len(correspondentes)}. "
            f"Instâncias: {nomes}. Nada foi alterado."
        )
    return correspondentes[0]


def luau(code):
    r = c.call("execute_luau", {"studio_id": sid, "datamodel_type": "Client", "code": code})
    return r.get("text", "")


def clicar(caminho):
    c.call("user_mouse_input", {"studio_id": sid, "datamodel_type": "Client", "actions": [
        {"action": "moveTo", "instance_path": caminho},
        {"action": "mouseButtonDown", "mouse_button": "left"}, {"action": "wait", "wait_time_ms": 120},
        {"action": "mouseButtonUp", "mouse_button": "left"}, {"action": "wait", "wait_time_ms": 1500}]})


def check(nome, ok, det=""):
    global falhas
    print(("OK    " if ok else "FALHA ") + nome + ("" if ok else " — " + det))
    falhas += 0 if ok else 1


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--studio-name", default="Moshoku-Prototipo.rbxlx",
                    help="trecho único do nome da janela de Studio alvo")
parser.add_argument("--list-studios", action="store_true",
                    help="lista as instâncias conectadas e não inicia Play")
args = parser.parse_args()
c = Client()
falhas = 0
sid = None
play_iniciado = False

try:
    studio = selecionar_studio(c, None if args.list_studios else args.studio_name)
    if studio is None:
        raise SystemExit(0)
    sid = studio["id"]
    estado = c.call("get_studio_state", {"studio_id": sid})
    if estado.get("isError") or "Current Studio Mode: Edit" not in estado.get("text", ""):
        raise RuntimeError(
            f"{studio['name']} precisa estar em Edit antes do teste. "
            "Play não foi iniciado."
        )
    inicio = c.call("start_stop_play", {"studio_id": sid, "is_start": True})
    if inicio.get("isError"):
        raise RuntimeError(inicio.get("text", "Falha ao iniciar Play no Studio alvo."))
    play_iniciado = True
    time.sleep(8)
    VIS = "return tostring(game.Players.LocalPlayer.PlayerGui.InicioJogo.MenuInicial.Visible)"
    clicar(PG + "Pagina_Inicio.Jogar")
    clicar(PG + "Pagina_Jogar.Treinar")
    time.sleep(2)
    check("treino começou e o menu fechou", "false" in luau(VIS), luau(VIS))
    clicar("LocalPlayer.PlayerGui.InicioJogo.Navegacao.MENU")
    time.sleep(3)  # snapshots chegam nesse intervalo
    check("MENU continua aberto durante a partida", "true" in luau(VIS), luau(VIS))
    check("opção Sair da partida visível", "true" in luau(
        "return tostring(game.Players.LocalPlayer.PlayerGui.InicioJogo.MenuInicial.Conteudo.Pagina_Inicio.SairPartida.Visible)"))
    clicar(PG + "Pagina_Inicio.SairPartida")
    time.sleep(2)
    fim = luau("return tostring(game.Players.LocalPlayer.PlayerGui.InicioJogo.MenuInicial.Conteudo.Pagina_Inicio.SairPartida.Visible)")
    check("depois de sair, a opção some (sem partida)", "false" in fim, fim)
finally:
    if play_iniciado:
        try:
            c.call("start_stop_play", {"studio_id": sid, "is_start": False})
        except Exception:
            pass
    c.close()
print("RESULTADO:", "tudo ok" if falhas == 0 else f"{falhas} falha(s)")

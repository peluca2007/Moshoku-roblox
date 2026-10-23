"""Cliques reais e captura das páginas A18 no Play já iniciado por A18.
Não inicia nem para Play. Prévia 375px limita o Frame, não simula celular.
"""
import json
import re
import shutil
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client

c = Client()
sid = c.studio_id()
report = []
def call(tool, **args):
    result = c.call(tool, dict(studio_id=sid, **args))
    assert not result.get("isError"), result
    return result["text"]
def lua(code):
    return call("execute_luau", datamodel_type="Client", code=code)
def check(label, value):
    report.append(("OK " if value else "FALHA ") + label)
    assert value, label
def press(path):
    coords = json.loads(lua("local o=" + path + "; local scroll=o:FindFirstAncestorWhichIsA('ScrollingFrame'); if scroll then scroll.CanvasPosition=Vector2.new(0,math.max(0,scroll.CanvasPosition.Y+o.AbsolutePosition.Y-scroll.AbsolutePosition.Y-scroll.AbsoluteSize.Y/2)) end; task.wait(.15); local p=o.AbsolutePosition+o.AbsoluteSize/2; return game.HttpService:JSONEncode({math.round(p.X),math.round(p.Y)})"))
    call("user_mouse_input", datamodel_type="Client", actions=[dict(action="mouseButtonClick", mouse_button="left", x=coords[0], y=coords[1])])
    time.sleep(.75)
def capture(name):
    result = call("screen_capture", capture_id=name)
    match = re.search(r"\[imagem salva em (.*?)\]", result)
    if match:
        shutil.copyfile(match[1], Path(__file__).with_name(name + Path(match[1]).suffix))
    print(result)

try:
    mode = call("get_studio_state")
    assert "Mode: Play" in mode, "A18 deve iniciar seu próprio Play primeiro"
    root = "game.Players.LocalPlayer.PlayerGui.InicioJogo"
    press(root + ".Navegacao.MENU")
    press(root + ".MenuInicial.Conteudo.Pagina_Inicio.Jogar")
    press(root + ".MenuInicial.Conteudo.Pagina_Jogar.Lutar")
    check("clique abre Desafios", "true" in lua("return " + root + ".MenuInicial.Conteudo.Pagina_Desafios.Visible"))
    capture("a18_desafios")
    press(root + ".MenuInicial.Conteudo.Pagina_Desafios.Voltar")
    press(root + ".MenuInicial.Conteudo.Pagina_Inicio.Jogar")
    press(root + ".MenuInicial.Conteudo.Pagina_Jogar.Duelo")
    check("clique abre PvP", "true" in lua("return " + root + ".MenuInicial.Conteudo.Pagina_PvP.Visible"))
    press(root + ".MenuInicial.Conteudo.Pagina_PvP.Equipe2")
    check("clique confirma Equipe 2", "Equipe 2" in lua("return " + root + ".MenuInicial.Conteudo.Pagina_PvP.SeuLado.Text"))
    capture("a18_pvp")
    lua("local f=" + root + ".MenuInicial; f.AnchorPoint=Vector2.new(.5,.5); f.Position=UDim2.fromScale(.5,.5); f.Size=UDim2.fromOffset(375,667); task.wait(.5); return 'preview 375x667'")
    press(root + ".MenuInicial.Conteudo.Pagina_PvP.Equipe0")
    check("clique confirma Sem equipe", "Sem equipe" in lua("return " + root + ".MenuInicial.Conteudo.Pagina_PvP.SeuLado.Text"))
    fits = json.loads(lua("local pg=" + root + ".MenuInicial.Conteudo; local out={}; for _,name in {'Pagina_Desafios','Pagina_PvP'} do for _,o in pg[name]:GetDescendants() do if o:IsA('TextLabel') and (o.Name=='Rotulo' or o.Name=='Descricao') then table.insert(out,{text=o.Text,fits=o.TextFits,width=o.AbsoluteSize.X}) end end end; return game.HttpService:JSONEncode(out)"))
    check("rotulos e descricoes A18 cabem em 375px", all(x["fits"] for x in fits))
    print(json.dumps(fits, ensure_ascii=False))
    capture("a18_pvp_375")
    press(root + ".MenuInicial.Conteudo.Pagina_PvP.Voltar")
    press(root + ".MenuInicial.Conteudo.Pagina_Inicio.Jogar")
    press(root + ".MenuInicial.Conteudo.Pagina_Jogar.Lutar")
    capture("a18_desafios_375")
    press(root + ".MenuInicial.Conteudo.Pagina_Desafios.Nivel3")
    time.sleep(1)
    check("clique inicia chefe real", "true" in lua("return game.Players.LocalPlayer.PlayerGui.HudJogo.Chefe.Visible"))
    capture("a18_arena")
finally:
    c.close()
    print("\n".join(report))

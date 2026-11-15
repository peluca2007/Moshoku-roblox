"""Cenários da suíte de QA. Cada função recebe `q` (Qa) e chama q.verificar(...). Veja qa.py/README.md."""
import json
import re

from qa_jogo import *  # noqa: F401,F403

ESTADO = {}  # memória entre cenários do mesmo Play (ex. dia antes de entrar)


def run_acao(q, acao, **campos):
    """Pede algo ao RunJogo como o cliente faria (para o que não tem botão). Espaça ≥0,5 s do pedido anterior."""
    time.sleep(0.6)
    t = ", ".join("%s=%s" % (k, json.dumps(v)) for k, v in campos.items())
    q.lua_cliente("game.ReplicatedStorage.RunJogo:FireServer({acao=%s%s}) return 'ok'" % (json.dumps(acao), (", " + t) if t else ""))
    time.sleep(1.2)


def botao_expedicao(q, nome):
    return q.achar(nome, GUI_EXP, "GuiButton")


def esperar_visao(q, campo, valor, timeout=15):
    return q.esperar(lambda: visao(q).get(campo) == valor, timeout, 1.5)


# ---------------------------------------------------------------- inicio
def inicio(q):
    criar_personagem(q)
    ok = q.esperar_lua("game.Players.LocalPlayer.PlayerGui:FindFirstChild('CriacaoRapida')", 5)
    q.verificar("tela de criação aparece", ok)
    q.foto("criacao0")
    q.clique(CRIACAO + "Area.Raca.Racas.Raca_humano")
    modelos = q.lua_cliente(PREVIA)
    q.verificar("prévia 3D tem modelo", modelos.isdigit() and int(modelos) > 0, "modelos=" + modelos)
    sel = q.lua_cliente("""local b=game.Players.LocalPlayer.PlayerGui.CriacaoRapida.Fundo.Moldura.Conteudo.Area.Raca.Racas.Raca_humano
local t={} for _,d in b:GetDescendants() do if d:IsA('GuiObject') and d.Name~='' then table.insert(t,d.Name) end end
return tostring(b:GetAttribute('Selecionada'))..'|'..table.concat(t,',')""")
    q.foto("criacao_raca", "criacao")
    avancar_criacao(q)
    q.verificar("passo Aparência aparece", "aparencia" in tela_de(q, "CriacaoRapida"), tela_de(q, "CriacaoRapida")[:80])
    avancar_criacao(q)
    nome = q.lua_cliente("""for _,d in game.Players.LocalPlayer.PlayerGui.CriacaoRapida:GetDescendants() do if d:IsA('TextBox') then return d.Text end end return ''""")
    q.verificar("nome preenchido", len(nome) >= 2, repr(nome))
    q.foto("criacao_nome")
    avancar_criacao(q)
    time.sleep(12)
    q.foto("mundo", "cidade")  # sem execute_luau logo antes: câmera do jogo intacta
    nasceu = q.esperar(lambda: q.lua_cliente("local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('CriacaoRapida') return tostring(g==nil or not g.Enabled)") == "true", 20, 2)
    q.verificar("criação some e o jogo começa", nasceu)
    time.sleep(2)
    q.verificar("faixa mostra Dia 1", dia_da_faixa(q) == 1, faixa(q)[:60])
    obj = objetivo(q)
    q.verificar("cartão de objetivo visível", len(obj) > 10, obj[:60])
    presas = q.lua_cliente("""local o={} for _,n in {'CriacaoRapida','CenaAbertura','Carregamento'} do local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild(n) if g and g.Enabled then table.insert(o,n) end end return table.concat(o,',')""")
    q.verificar("nenhuma tela cheia presa", presas == "", presas)
    ESTADO["dia"] = dia_da_faixa(q)


# ---------------------------------------------------------------- porta_sem_arvore
def porta_sem_arvore(q):
    antes = dia_da_faixa(q)
    p = abrir_painel_porta(q)
    q.verificar("painel da porta abre", bool(p), tela(q)[:100])
    if p:
        q.clique(p, 2500)
    aviso = tela(q, 80, 4000).replace(" ", "")
    q.verificar("recusa com aviso", "naofoipossivel" in aviso or "naopodelutar" in aviso or "aindanaopode" in aviso, aviso[:140])
    q.foto("recusa")
    q.verificar("dia não muda", dia_da_faixa(q) == antes, "antes=%s depois=%s" % (antes, dia_da_faixa(q)))
    q.verificar("avatar não ficou ancorado", not ancorado(q))
    q.verificar("não entrou em luta", not combate(q))
    q.clicar_nome("Cancelar", GUI_EXP)


# ---------------------------------------------------------------- primeira_arvore
def primeira_arvore(q):
    notas = ladino(q)
    time.sleep(2)
    obj = objetivo(q)
    q.verificar("objetivo passa a 'Vá até a porta do esgoto'", "portadoesgoto" in obj, "%s | %s" % (obj[:80], notas))
    q.foto("objetivo_porta")


# ---------------------------------------------------------------- esgoto_sala1
def esgoto_sala1(q):
    antes = dia_da_faixa(q)
    ESTADO["dia_antes_run"] = antes
    q.verificar("botão de entrar existe", entrar_no_esgoto(q), tela(q)[:100])
    time.sleep(1)
    q.verificar("dia +1 ao entrar", dia_da_faixa(q) == (antes or 0) + 1, "antes=%s depois=%s" % (antes, dia_da_faixa(q)))
    f = faixa(q)
    q.verificar("faixa mostra Sala 1/5", re.search(r"sala 1\s*5", f) is not None, f[:70])
    q.verificar("combate começa em 15 s", bool(q.esperar(lambda: combate(q), 15, 1)))
    time.sleep(3)
    q.foto("combate", "luta_hud")
    t = tela(q)
    q.verificar("interface de combate visível", "encerrarturno" in t.replace(" ", ""), t[:90])
    q.verificar("avatar ancorado na luta", ancorado(q))


# ---------------------------------------------------------------- luta
def luta(q):
    a = acao_luta(q, "disparo")
    q.foto("disparo", "luta_disparo")
    q.verificar("disparo enviado na luta", a == "disparo", a)
    time.sleep(2.5)
    a = acao_luta(q, "golpe", 14)
    q.foto("golpe", "luta_golpe")
    q.verificar("golpe corpo a corpo enviado", a == "golpe", a)
    r = lutar(q)
    q.verificar("bot venceu a luta", "fase=vitoria" in r, r[:120])
    time.sleep(1)
    res = tela_de(q, "ResultadoPartida", 600)
    q.verificar("tela de resultado aparece", res != "", "texto=" + res[:60])
    q.foto("resultado", "resultado")
    sumiu = q.esperar(lambda: tela_de(q, "ResultadoPartida", 600) == "", 12, 2)
    if not sumiu:  # observado: não some sozinha; o botão "Continuar" (Campo) fecha
        clicar_visivel(q, "ResultadoPartida")
        sumiu = q.esperar(lambda: tela_de(q, "ResultadoPartida", 600) == "", 8, 1)
    q.verificar("tela de resultado some", bool(sumiu), tela_de(q, "ResultadoPartida", 600)[:60])
    q.verificar("fase vira acampamento", bool(q.esperar(lambda: visao(q).get("fase") == "acampamento", 15, 2)), str(visao(q).get("fase")))
    q.verificar("avatar ancorado no acampamento", ancorado(q))
    q.verificar("interface de combate some", not combate(q))
    q.foto("acampamento", "acampamento")


# ---------------------------------------------------------------- acampamento
def acampamento(q):
    d0 = dia_da_faixa(q)
    v0 = visao(q)
    b = botao_expedicao(q, "Descansar")
    q.verificar("botão Descansar existe", bool(b), tela(q)[:100])
    if b:
        q.clique(b, 2000)
        v = visao(q)
        q.verificar("descansar gasta meio dia", abs((v0.get("diasRestantes", 0) - v.get("diasRestantes", 0)) - 0.5) < 0.01,
                    "%s -> %s" % (v0.get("diasRestantes"), v.get("diasRestantes")))
        q.verificar("contador de descansos 1/2", re.search(r"1\s*2", faixa(q) + tela_de(q, GUI_EXP, 900)) is not None, tela_de(q, GUI_EXP, 900)[-100:])
    q.foto("descansou")
    b = botao_expedicao(q, "LevantarAcampamento")
    q.verificar("botão Levantar acampamento existe", bool(b))
    if b:
        q.clique(b, 2000)
    ids = visao(q).get("ids", [])
    q.verificar("aparecem escolhas de caminho", len(ids) >= 1, str(ids))
    q.foto("caminhos", "escolhas")
    if ids:
        e = botao_expedicao(q, "Escolher_" + ids[0])
        if e:
            q.clique(e, 3000)
    q.verificar("sala 2 começa com luta", bool(q.esperar(lambda: combate(q), 20, 1)) and re.search(r"sala 2", faixa(q)) is not None, faixa(q)[:60])
    q.foto("sala2")


# ---------------------------------------------------------------- esgoto_completo
def fechar_resultado(q):
    if tela_de(q, "ResultadoPartida", 600):
        clicar_visivel(q, "ResultadoPartida", 1000)


def esgoto_completo(q):
    # estamos numa sala em luta ou acampamento; repete luta/acampamento até o chefe e a volta à cidade
    derrota = False
    v = visao(q)
    if v.get("galho") == "cidade" and "entrar-esgoto" in v.get("ids", []):  # recomeço depois de derrota/volta
        entrar_no_esgoto(q)
        q.esperar(lambda: combate(q), 20, 1)
    for rodada in range(9):
        v = visao(q)
        if rodada > 0 and v.get("galho") == "cidade":
            break
        if v.get("fase") == "luta" or combate(q):
            r = lutar(q)
            q.esperar(lambda: visao(q).get("fase") != "luta", 20, 2)
            if visao(q).get("fase") == "luta":
                q.verificar("luta do passo %s terminou" % v.get("passo"), False, "bot=" + r, foto=True)
                return
            if visao(q).get("galho") == "cidade":
                derrota = True
                q.verificar("derrota no passo %s (bot)" % v.get("passo"), True)
        time.sleep(2)
        fechar_resultado(q)
        v = visao(q)
        if v.get("galho") == "cidade":
            break
        b = botao_expedicao(q, "LevantarAcampamento")
        if b:
            q.clique(b, 2000)
        ids = [i for i in visao(q).get("ids", []) if i != "voltar-a-cidade"]
        if "voltar-com-a-recompensa" in ids:
            q.foto("chefe_vencido")
            e = botao_expedicao(q, "Escolher_voltar-com-a-recompensa")
            if e:
                q.clique(e, 3000)
            break
        pref = "enfrentar-o-chefe" if "enfrentar-o-chefe" in ids else (ids[0] if ids else None)
        if not pref:
            q.verificar("há caminho a escolher", False, str(visao(q))[:140], foto=True)
            return
        e = botao_expedicao(q, "Escolher_" + pref)
        if e:
            q.clique(e, 3000)
        q.esperar(lambda: combate(q), 20, 1)
    if derrota:
        q.verificar("derrota: grupo volta à cidade", visao(q).get("galho") == "cidade")
        q.verificar("derrota: avatar solto", not ancorado(q))
        q.verificar("derrota: campanha continua (pode entrar de novo)", any(i == "entrar-esgoto" or i.startswith("retomar") for i in visao(q).get("ids", [])), str(visao(q).get("ids")))
        q.foto("derrota")
        return
    v = visao(q)
    q.verificar("volta à cidade (galho cidade)", bool(q.esperar(lambda: visao(q).get("galho") == "cidade", 20, 2)), str(visao(q).get("galho")))
    v = visao(q)
    q.verificar("avatar solto na cidade", not ancorado(q))
    ids = v.get("ids", [])
    q.verificar("entrar-esgoto e retomar somem do hub", "entrar-esgoto" not in ids and not any(i.startswith("retomar") for i in ids), str(ids))
    q.verificar("opção selar-a-anomalia aparece", "selar-a-anomalia" in ids, str(ids))
    ouro = q.lua_servidor("""local p=game.Players:GetPlayers()[1] local a={} for k,v in p:GetAttributes() do table.insert(a,k..'='..tostring(v)) end return table.concat(a,' ')""")
    ESTADO["atrs"] = ouro
    q.verificar("ouro da expedição aparece na tela", "ouro" in tela(q) or "recompensa" in tela(q), tela(q)[:100])
    q.foto("cidade_pos_esgoto")
    # selar a anomalia: fim da campanha
    p = abrir_painel_porta(q)
    e = botao_expedicao(q, "Escolher_selar-a-anomalia")
    if e:
        q.clique(e, 3000)
        q.verificar("selar leva ao final da campanha", bool(q.esperar(lambda: visao(q).get("galho") == "final-campanha" or visao(q).get("fim"), 15, 2)), str(visao(q))[:140])
        q.foto("final")
    else:
        q.verificar("botão selar-a-anomalia existe", False, "ids=%s painel=%s" % (visao(q).get("ids"), bool(p)), foto=True)


# ---------------------------------------------------------------- voltar_e_retomar
def voltar_e_retomar(q):
    v = visao(q)
    if v.get("fase") == "luta" or combate(q):
        lutar(q)
        q.esperar(lambda: visao(q).get("fase") == "acampamento", 20, 2)
        time.sleep(2)
        fechar_resultado(q)
    v = visao(q)
    passo, d0 = v.get("passo"), v.get("diasRestantes")
    q.verificar("está no acampamento antes de voltar", v.get("fase") == "acampamento", str(v.get("fase")))
    b = botao_expedicao(q, "VoltarCidade")
    q.verificar("botão Voltar à cidade existe", bool(b))
    if b:
        q.clique(b, 1500)
        if visao(q).get("galho") != "cidade":  # pode pedir confirmação em dois toques
            q.clique(b, 2500)
    q.esperar(lambda: visao(q).get("galho") == "cidade", 10, 1.5)
    v = visao(q)
    q.verificar("voltou à cidade", v.get("galho") == "cidade", str(v.get("galho")))
    q.verificar("dias gastos pelo passo", d0 is not None and v.get("diasRestantes", 99) < d0, "passo %s: %s -> %s" % (passo, d0, v.get("diasRestantes")))
    q.verificar("avatar solto na cidade", not ancorado(q))
    t = tela(q)
    q.verificar("sem evento de viagem antigo", "viajando" not in t and "viagem" not in t, t[:90])
    ids = v.get("ids", [])
    retomar = next((i for i in ids if i.startswith("retomar")), None)
    q.verificar("opção de retomar aparece no hub", retomar is not None, str(ids))
    if not retomar:
        return
    abrir_painel_porta(q)
    q.foto("hub_retomar")
    r = botao_expedicao(q, "Escolher_" + retomar)
    q.verificar("botão de retomar existe", bool(r))
    if r:
        q.clique(r, 3500)
        time.sleep(2)
        v = visao(q)
        q.verificar("retomou no mesmo passo", v.get("passo") == passo, "passo=%s esperado=%s" % (v.get("passo"), passo))
        q.verificar("retomar não repete a luta", v.get("fase") != "luta" and not combate(q), "fase=%s" % v.get("fase"))
        q.foto("retomou")


# ---------------------------------------------------------------- menu
def menu(q):
    sob = q.lua_cliente("""local pg=game.Players.LocalPlayer.PlayerGui local r={}
for _,p in {{'InicioJogo','MENU'},{'RunJogo','AtalhoRun'},{'ContaJogo','AtalhoConta'},{'AjudaJogo','AtalhoAjuda'}} do local d=pg[p[1]]:FindFirstChild(p[2],true) if d then table.insert(r,{p[2],d.AbsolutePosition,d.AbsoluteSize}) end end
local o={} for i=1,#r do for j=i+1,#r do local a,b=r[i],r[j]
 if a[2].X<b[2].X+b[3].X and b[2].X<a[2].X+a[3].X and a[2].Y<b[2].Y+b[3].Y and b[2].Y<a[2].Y+a[3].Y then table.insert(o,a[1]..'x'..b[1]) end end end
return table.concat(o,',')""")
    q.verificar("atalhos do topo não se sobrepõem", sob == "", "sobrepostos: " + sob, foto=bool(sob))
    # (nome, ScreenGui, botão do atalho, foto estável)
    for nome, gui, atalho, estavel in [("MENU", "InicioJogo", "MENU", "menu"), ("DIÁRIO", "RunJogo", "AtalhoRun", "diario"),
                                       ("CONTA", "ContaJogo", "AtalhoConta", "conta"), ("AJUDA", "AjudaJogo", "AtalhoAjuda", "ajuda")]:
        b = q.achar(atalho, gui, "GuiButton")
        q.verificar("%s: atalho existe" % nome, bool(b))
        if not b:
            continue
        outros = lambda: " ".join(tela_de(q, g, 900) for g in ("InicioJogo", "RunJogo", "ContaJogo", "AjudaJogo") if g != gui)
        antes_g, antes_o = tela_de(q, gui, 900), outros()
        q.clique(b, 800)
        q.esperar(lambda: tela_de(q, gui, 900) != antes_g, 4, 0.8)
        aberto = tela_de(q, gui, 900)
        ok = aberto != antes_g
        det = "%d -> %d chars; texto dos outros painéis %s" % (len(antes_g), len(aberto), "mudou (abriu OUTRO painel)" if outros() != antes_o else "igual")
        q.verificar("%s abre" % nome, ok, det, foto=not ok)
        if not ok and nome == "DIÁRIO":
            q.clicar_nome("Fechar", "AjudaJogo")
            # contorno só do teste: afasta o atalho para o clique não cair no vizinho e conseguir ver o painel
            q.lua_cliente("local b=game.Players.LocalPlayer.PlayerGui.RunJogo:FindFirstChild('AtalhoRun',true) b.Position=UDim2.fromOffset(1130,14) return 'ok'")
            b = q.achar(atalho, gui, "GuiButton")
            q.clique(b, 800)
            q.esperar(lambda: tela_de(q, gui, 900) != antes_g, 4, 0.8)
            aberto = tela_de(q, gui, 900)
        time.sleep(1)
        q.foto("menu_" + nome.lower(), estavel)
        if gui == "InicioJogo":  # o menu só fecha por "Continuar", no fim da lista: observa se está visível sem rolar
            fora = q.lua_cliente("""local c=game.Players.LocalPlayer.PlayerGui.InicioJogo:FindFirstChild('Continuar',true) local v=workspace.CurrentCamera.ViewportSize
return tostring(c ~= nil and (c.AbsolutePosition.Y + c.AbsoluteSize.Y > v.Y))""")
            q.verificar("MENU: botão de fechar visível sem rolar", fora == "false", "Continuar fica abaixo da borda; sem X nem atalho visível")
            q.lua_cliente("""for _,d in game.Players.LocalPlayer.PlayerGui.InicioJogo:GetDescendants() do if d:IsA('ScrollingFrame') and d.Visible and d.AbsoluteSize.X>100 then d.CanvasPosition=Vector2.new(0,d.AbsoluteCanvasSize.Y) end end return 'ok'""")
            time.sleep(1)
            q.clicar_nome("Continuar", gui)
        else:
            q.clicar_nome("Fechar", gui) or q.clique(b, 800)
        fechou = q.esperar(lambda: tela_de(q, gui, 900) == antes_g, 5, 0.8)
        q.verificar("%s fecha" % nome, bool(fechou) or aberto == antes_g, "%d chars" % len(tela_de(q, gui, 900)))
    q.verificar("nada preso por cima", not combate(q) and tela_de(q, "AjudaJogo", 900).count("fechar") == 0 and not tela_de(q, "ContaJogo", 900).startswith("fechar"))


# ---------------------------------------------------------------- area_de_testes
def area_de_testes(q):
    # estado limpo: fora da sala e painel fechado (sobra de execução anterior)
    if q.lua_servidor("return tostring(game.Players:GetPlayers()[1]:GetAttribute('NaAreaDeTestes'))") == "true":
        if "criaturas" not in tela_de(q, "AreaDeTestes", 900):
            q.tecla("F6", 150, 1000)
        clicar_texto(q, "AreaDeTestes", "Sair", 3000)
    if "criaturas" in tela_de(q, "AreaDeTestes", 900):
        q.tecla("F6", 150, 1000)
    origem = q.lua_servidor("local c=game.Players:GetPlayers()[1].Character return tostring(c.HumanoidRootPart.Position)")
    q.tecla("F6", 150, 1500)
    t = tela_de(q, "AreaDeTestes", 900)
    q.verificar("F6 abre o painel", "criaturas" in t, t[:80])
    q.foto("testes_painel")
    clicar_texto(q, "AreaDeTestes", "Criaturas", 600)
    q.verificar("botão Entrar existe", bool(clicar_texto(q, "AreaDeTestes", "Entrar", 4000)))
    pos = q.lua_servidor("local c=game.Players:GetPlayers()[1].Character return tostring(c.HumanoidRootPart.Position)")
    q.verificar("Entrar leva à sala (x≈4000)", pos.startswith("39") or pos.startswith("40"), pos)
    # criaturas
    for nome in ["aranha-da-floresta", "goblin-batedor", "lobo-cinzento"]:
        clicar_texto(q, "AreaDeTestes", nome, 500)
        n = q.esperar(lambda: vitrine(q).split("|")[0] not in ("0", ""), 6, 1) and vitrine(q)
        q.verificar("criatura %s aparece na Vitrine" % nome, bool(n), str(n))
    for anim in ["andando", "ataque", "queda", "parado"]:
        clicar_texto(q, "AreaDeTestes", anim, 700)
    time.sleep(1)
    clicar_texto(q, "AreaDeTestes", "ataque", 200)
    q.foto("testes_criaturas", "testes_criaturas")
    # props
    clicar_texto(q, "AreaDeTestes", "Props", 900)
    t = clicar_na_lista(q, "AreaDeTestes", 1, 700)
    n = vitrine(q)
    q.verificar("prop '%s' aparece" % t[:20], n.split("|")[0] not in ("0", ""), n)
    q.foto("testes_props", "testes_props")
    # arenas
    clicar_texto(q, "AreaDeTestes", "Arenas", 900)
    t = clicar_na_lista(q, "AreaDeTestes", 1, 2500)
    p2 = q.lua_servidor("local c=game.Players:GetPlayers()[1].Character return tostring(c.HumanoidRootPart.Position)")
    q.verificar("arena '%s' monta e leva o avatar" % t[:20], p2 != pos, p2)
    q.foto("testes_arena", "testes_arena")
    # sons e voz
    clicar_texto(q, "AreaDeTestes", "Sons", 900)
    for i in (1, 3):
        clicar_na_lista(q, "AreaDeTestes", i, 150)
        s = som_tocando(q)
        q.verificar("som %d toca" % i, s != "", s)
    clicar_texto(q, "AreaDeTestes", "Vozes", 900)
    clicar_na_lista(q, "AreaDeTestes", 1, 150)
    s = q.esperar(lambda: som_tocando(q), 4, 0.5)
    q.verificar("voz toca", bool(s), str(s))
    # gestos
    clicar_texto(q, "AreaDeTestes", "Gestos", 900)
    for i in (1, 2, 3):
        t = clicar_na_lista(q, "AreaDeTestes", i, 600)
        q.verificar("gesto %d (%s) sem erro" % (i, t[:18]), bool(t))
    q.foto("testes_gestos", "testes_gestos")
    clicar_texto(q, "AreaDeTestes", "Interface", 900)
    t = clicar_na_lista(q, "AreaDeTestes", 1, 1200)
    q.verificar("aba Interface mostra uma tela de amostra", bool(t), t)
    q.foto("testes_interface", "testes_interface")
    clicar_texto(q, "AreaDeTestes", "Sair", 3000)
    fim = q.lua_servidor("local c=game.Players:GetPlayers()[1].Character return tostring(c.HumanoidRootPart.Position)")
    q.verificar("Sair devolve ao ponto de origem", abs(float(fim.split(",")[0]) - float(origem.split(",")[0])) < 15 and abs(float(fim.split(",")[2]) - float(origem.split(",")[2])) < 15, "origem=%s fim=%s" % (origem, fim))


# ---------------------------------------------------------------- specs
def specs(q):
    """Specs do servidor no Play (inclui os que só rodam no Studio, ex. RunServicoExpedicao). ~3 min."""
    if not q.play:
        q.play_ligar()
        time.sleep(10)
    q.console_erros()  # zera o ponteiro: só interessa o que os specs imprimirem
    r = q.lua("local s=game.ServerScriptService.Server local p,f=require(s.TestRunner).run(s.tests) return p..' ok, '..f..' falha(s)'", "Server", 600, 1)
    m = re.search(r"(\d+) ok, (\d+) falha", r)
    texto = q.chamar("get_console_output", {}, 60, 2)
    falhas = [l.strip()[:150] for l in texto.splitlines() if re.search(r"\[Testes\] (FALHA|.*não carregou)", l)]
    q.verificar("specs do servidor: " + (m.group(0) if m else r[:60]), bool(m) and m.group(2) == "0", "; ".join(falhas[:5]))
    for f in falhas[:5]:
        print("  spec> " + f, flush=True)
    q.linhas_console = len(texto.splitlines())

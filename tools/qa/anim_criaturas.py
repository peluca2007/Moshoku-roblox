"""ANIM2b: captura quadros de cada estado (parado, andando, ataque, dano, morte) das criaturas Quaternius em Play.
Monta um palco em x=5000 com CriaturaAnimada (a mesma classe da luta) e fixa a câmera. Salva
build/beleza/anim/criaturas_studio_<criatura>_<estado>_<n>.jpg e criaturas_prancha_studio.jpg.
Uso: python tools/qa/anim_criaturas.py [criatura ...]   (Studio aberto com MCP; sincronize antes: tools/studio_sync.py)"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qa_lib import Qa, RAIZ  # noqa: E402

SAIDA = os.path.join(RAIZ, "build", "beleza", "anim")
IDS = {"rato": "creature/rato-gigante", "aranha": "creature/aranha-da-floresta",
       "esqueleto": "creature/esqueleto-andarilho", "dragao": "creature/dragao-azul",
       "morcego": "creature/morcego-gigante", "serpente": "creature/serpente-de-fogo",
       "lobo": "creature/lobo-cinzento", "goblin": "creature/goblin-batedor"}
ESTADOS = ["parado", "andando", "ataque", "dano", "morte"]

SERVIDOR = r"""
local RS = game:GetService("ReplicatedStorage")
local S = game:GetService("ServerScriptService").Server
local CA = require(S.Mundo.CriaturaAnimada)
local MC = require(RS.Shared.Mundo.ModelosCriaturas)
local MM = require(S.Mundo.MontarModelo)
local P = Vector3.new(5000, 60, 5000)
local palco = workspace:FindFirstChild("PalcoAnim") or Instance.new("Folder")
palco.Name = "PalcoAnim"; palco.Parent = workspace
if not palco:FindFirstChild("Chao") then
	local c = Instance.new("Part"); c.Name = "Chao"; c.Anchored = true; c.Size = Vector3.new(60, 1, 60)
	c.Position = P - Vector3.new(0, 0.5, 0); c.Color = Color3.fromRGB(90, 100, 90); c.Parent = palco
end
local atual, idAtual, ultimo, montando = nil, nil, 0, false
game:GetService("RunService").Heartbeat:Connect(function(dt)
	local id, est = workspace:GetAttribute("AnimId"), workspace:GetAttribute("AnimEst")
	if not id or montando then return end
	if id ~= idAtual and not montando then
		montando = true
		if atual then atual:destruir(); atual = nil end
		idAtual = id
		local info = MC.escolher(id, 1, MM.existe)
		atual = info and CA.montar(info, palco, CFrame.new(P), info.escalaMundo)
		if atual then local t = atual:tamanho(); workspace:SetAttribute("AnimTam", math.max(t.X, t.Y, t.Z)) end
		montando = false
	end
	if not atual then return end
	local agora = os.clock()
	local dado = workspace:GetAttribute("AnimReset")
	if dado then workspace:SetAttribute("AnimReset", nil); atual.quedaDesde = nil; atual.acao = nil; atual.golpeDesde = nil; ultimo = 0 end
	if est == "ataque" and agora - ultimo > 1.6 then ultimo = agora; atual:golpear(agora, function() workspace:SetAttribute("AnimImpacto", agora) end)
	elseif est == "dano" and agora - ultimo > 1.2 then ultimo = agora; atual:levarGolpe(agora)
	elseif est == "morte" and not atual:caiu() then atual:cair(agora) end
	atual:atualizar(dt, CFrame.new(P), est == "andando", 4, nil, agora)
end)
return "ok"
"""

CLIENTE = r"""
local RS = game:GetService("RunService")
pcall(function() RS:UnbindFromRenderStep("AnimCam") end)
RS:BindToRenderStep("AnimCam", Enum.RenderPriority.Last.Value + 1, function()
	for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false end
	end
	local cam = workspace.CurrentCamera
	local tam = workspace:GetAttribute("AnimTam") or 4
	local P = Vector3.new(5000, 60, 5000)
	local alvo = P + Vector3.new(0, tam * 0.35, 0)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(alvo + Vector3.new(tam * 0.7, tam * 0.4, -tam * 1.0), alvo)
end)
return "ok"
"""


def main(nomes):
    from PIL import Image
    os.makedirs(SAIDA, exist_ok=True)
    q = Qa()
    q.cenario = "criaturas_studio"
    q.play_ligar()
    time.sleep(8)
    q.lua_servidor(SERVIDOR)
    q.lua_cliente(CLIENTE)
    linhas = []
    for nome in nomes:
        q.lua_servidor("workspace:SetAttribute('AnimId','%s') workspace:SetAttribute('AnimEst','parado') return 'ok'" % IDS[nome])
        time.sleep(3)
        for est in ESTADOS:
            q.lua_servidor("workspace:SetAttribute('AnimReset',true) workspace:SetAttribute('AnimEst','%s') return 'ok'" % est)
            time.sleep(0.5)
            imgs = []
            for i in range(5):
                p = q.foto("%s_%s_%d" % (nome, est, i))
                im = Image.open(os.path.join(RAIZ, p)).convert("RGB")
                w, h = im.size
                im = im.crop((int(w * 0.3), int(h * 0.2), int(w * 0.7), int(h * 0.8)))
                im.save(os.path.join(SAIDA, "criaturas_studio_%s_%s_%d.jpg" % (nome, est, i)), quality=80)
                imgs.append(im)
                time.sleep(0.12)
            linhas.append(imgs)
    q.lua_cliente("pcall(function() game:GetService('RunService'):UnbindFromRenderStep('AnimCam') end) return 'ok'")
    q.play_parar()
    tw, th = 200, 200
    prancha = Image.new("RGB", (tw * 5, th * len(linhas)), (20, 20, 20))
    for r, imgs in enumerate(linhas):
        for c, im in enumerate(imgs):
            prancha.paste(im.resize((tw, th)), (c * tw, r * th))
    prancha.save(os.path.join(SAIDA, "criaturas_prancha_studio.jpg"), quality=75)
    print("prancha:", len(linhas), "linhas")


if __name__ == "__main__":
    main(sys.argv[1:] or ["rato", "aranha", "esqueleto", "dragao"])

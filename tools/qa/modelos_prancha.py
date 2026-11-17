"""MOD5: prancha dos humanoides Quaternius armados no Studio (CriaturaAnimada, a mesma classe da luta).
Uso: python tools/qa/modelos_prancha.py   (Studio livre: lock build/qa/STUDIO_EM_USO.txt; Studio com foco)
Salva build/beleza/mod5/prancha_estudio.jpg e confere o contrato da peça `Arma` (nome, TipoArma, soltarArma)."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_criaturas as A  # noqa: E402
from qa_lib import Qa, RAIZ  # noqa: E402

SAIDA = os.path.join(RAIZ, "build", "beleza", "mod5")
# (rótulo, criatura, variante)
ITENS = [("bandido_espada", "creature/bandido-de-estrada", 1), ("bandido_porrete", "creature/bandido-de-estrada", 0),
         ("goblin_adaga", "creature/goblin-batedor", 0)]
ESTADOS = ["parado", "ataque", "dano", "morte"]
SERVIDOR = A.SERVIDOR.replace("MC.escolher(id, 1, MM.existe)", 'MC.escolher(id, workspace:GetAttribute("AnimVar") or 1, MM.existe)') + """
"""
CONTRATO = r"""
local S = game:GetService("ServerScriptService").Server
local CA = require(S.Mundo.CriaturaAnimada)
local MC = require(game.ReplicatedStorage.Shared.Mundo.ModelosCriaturas)
local MM = require(S.Mundo.MontarModelo)
local palco = workspace.PalcoAnim
local saida = {}
for _, v in {{"creature/bandido-de-estrada", 1}, {"creature/bandido-de-estrada", 0}, {"creature/goblin-batedor", 0}, {"creature/rato-gigante", 0}} do
	local info = MC.escolher(v[1], v[2], MM.existe)
	local c = CA.montar(info, palco, CFrame.new(5000, 60, 5100), 1)
	local arma = c.modelo:FindFirstChild("Arma", true)
	table.insert(saida, info.modulo .. ":" .. (if arma then (arma.ClassName .. "/" .. tostring(arma:GetAttribute("TipoArma")) .. "/" .. tostring(arma:GetAttribute("Empunhadura"))) else "sem arma"))
	if arma then
		local r = c:soltarArma()
		table.insert(saida, "  solta: " .. tostring(r and r.principal.Anchored) .. " " .. tostring(r and #r.demais))
		for _, p in r.demais do p:Destroy() end
	end
	c.modelo:Destroy()
end
return table.concat(saida, "\n")
"""


def main():
    from PIL import Image
    os.makedirs(SAIDA, exist_ok=True)
    q = Qa()
    q.cenario = "mod5"
    q.play_ligar()
    time.sleep(8)
    q.lua_servidor(SERVIDOR)
    q.lua_cliente(A.CLIENTE)
    linhas = []
    for rotulo, cid, var in ITENS:
        q.lua_servidor("workspace:SetAttribute('AnimId','creature/rato-gigante') return 'ok'")  # força remontar (a variante só vale na montagem)
        time.sleep(2)
        q.lua_servidor("workspace:SetAttribute('AnimId','%s') workspace:SetAttribute('AnimVar',%d) workspace:SetAttribute('AnimEst','parado') return 'ok'" % (cid, var))
        time.sleep(3)
        for est in ESTADOS:
            q.lua_servidor("workspace:SetAttribute('AnimReset',true) workspace:SetAttribute('AnimEst','%s') return 'ok'" % est)
            time.sleep(0.5)
            imgs = []
            for i in range(3):
                p = q.foto("%s_%s_%d" % (rotulo, est, i))
                im = Image.open(os.path.join(RAIZ, p)).convert("RGB")
                w, h = im.size
                im = im.crop((int(w * 0.3), int(h * 0.05), int(w * 0.7), int(h * 0.95)))
                if i == 1 and est == "parado":
                    im.save(os.path.join(SAIDA, "%s_parado.png" % rotulo))
                imgs.append(im)
                time.sleep(0.15)
            linhas.append(imgs)
    print(q.lua_servidor(CONTRATO))
    q.lua_cliente("pcall(function() game:GetService('RunService'):UnbindFromRenderStep('AnimCam') end) return 'ok'")
    q.play_parar()
    tw, th = 220, 260
    prancha = Image.new("RGB", (tw * 3 * 2, th * ((len(linhas) + 1) // 2)), (20, 20, 20))
    for r, imgs in enumerate(linhas):
        for c, im in enumerate(imgs):
            prancha.paste(im.resize((tw, th)), ((r % 2) * tw * 3 + c * tw, (r // 2) * th))
    prancha.save(os.path.join(SAIDA, "prancha_estudio.jpg"), quality=80)
    print("prancha:", len(linhas), "linhas")


if __name__ == "__main__":
    main()

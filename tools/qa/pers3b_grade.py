"""PERS3b: grade de variações (cabelos, barbas, rostos, peças) montada com ModeloAparencia.criarR15 num ViewportFrame
próprio sobre a criação (Play ligado, cliente com a criação aberta). Uso: python tools/qa/pers3b_grade.py"""
import time, json
import pers3b_lib as L

LUA = """local PG=game.Players.LocalPlayer.PlayerGui
local old=PG:FindFirstChild('XVP') if old then old:Destroy() end
local MA=require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild('ModeloAparencia',true))
local Ap=require(game.ReplicatedStorage.Shared.Aparencia.Aparencia)
local Ca=require(game.ReplicatedStorage.Shared.Aparencia.Catalogo)
local g=Instance.new('ScreenGui') g.Name='XVP' g.DisplayOrder=999 g.IgnoreGuiInset=true g.Parent=PG
local v=Instance.new('ViewportFrame') v.Size=UDim2.fromScale(1,1) v.BackgroundColor3=Color3.fromRGB(60,55,50) v.Ambient=Color3.fromRGB(200,190,170) v.LightColor=Color3.fromRGB(220,210,190) v.LightDirection=Vector3.new(-1,-1,-1) v.Parent=g
local w=Instance.new('WorldModel') w.Parent=v
local cam=Instance.new('Camera') cam.FieldOfView=FOV30 v.CurrentCamera=cam cam.Parent=v
local itens=%s
local n=#itens
for i,it in itens do
  local a=Ap.padrao(it.raca or 'race/humano',it.semente or 3)
  a.barba=it.barba or 'BarbaNenhum' a.cabelo=it.cabelo or 'CabeloNenhum' a.roupas=it.roupas or {}
  if it.cores then for k,c in it.cores do a.cores[k]=c end end
  if it.rosto then for k,c in it.rosto do a.rosto[k]=c end end
  local ok,m=pcall(MA.criarR15,a,it.raca or 'race/humano')
  if ok then m.Parent=w m:PivotTo(CFrame.new((i-(n+1)/2)*%s,0,0)*CFrame.Angles(0,math.rad(%s),0)) else warn('GRADE '..tostring(m)) end
end
cam.CFrame=CFrame.lookAt(Vector3.new(0,%s,-%s),Vector3.new(0,%s,0))
return 'ok '..n"""
def lua_tab(x):
    if isinstance(x, dict): return "{" + ",".join('["%s"]=%s' % (k, lua_tab(v)) for k, v in x.items()) + "}"
    if isinstance(x, list): return "{" + ",".join(lua_tab(i) for i in x) + "}"
    if isinstance(x, str): return '"%s"' % x
    return str(x)


def grade(q, nome, itens, esp=3.6, ang=20, ty=1.6, dist=9, fov=30):
    q.lua_cliente(LUA.replace("FOV30", str(fov)) % (lua_tab(itens), esp, ang, ty, dist, ty), timeout=120)
    time.sleep(5)
    return q.foto(nome)


if __name__ == "__main__":
    q = L.Qa(); q.cenario = "grade"
    CAB = ["CabeloCurto1", "CabeloMasculino1", "CabeloLongo1", "CabeloRabo1", "CabeloEspetado1", "CabeloTrancado1", "CabeloCoque1", "CabeloBob1"]
    COR = ["CabeloCastanho", "CabeloPreto", "CabeloLoiro", "CabeloRuivo", "CabeloAzul", "CabeloBranco", "CabeloCastanho", "CabeloPreto"]
    try:
        f = []
        for k in (0, 4):
            f.append(grade(q, "cab%d" % k, [{"cabelo": CAB[i], "cores": {"cabelo": COR[i]}} for i in range(k, k + 4)]))
        L.montagem(f, "build/qa/pers3b/g_cabelos.png", (0, 150, 1411, 520))
        f = [grade(q, "barba", [{"cabelo": "CabeloCurto1", "barba": b, "cores": {"cabelo": "CabeloCastanho"}} for b in ("Barba1", "BarbaLonga1", "BarbaCavanhaque1")]
                   + [{"raca": "race/elfo", "cabelo": "CabeloLongo1", "cores": {"cabelo": "CabeloLoiro"}}]),
             grade(q, "racas_tracos", [{"raca": r, "cabelo": "CabeloCurto1"} for r in ("race/elfo", "race/raca-fera", "race/anao", "race/hobbit")])]
        L.montagem(f, "build/qa/pers3b/g_barbas.png", (0, 150, 1411, 520))
        f = [grade(q, "rostos", [{"cabelo": "CabeloCurto1", "rosto": r, "cores": {"olho": o}} for r, o in (
            ({"olhos": "OlhoQuadrado"}, "OlhoAzul"), ({"olhos": "OlhoFeliz", "boca": "BocaSorriso"}, "OlhoVerde"),
            ({"olhos": "OlhoBravo", "sobrancelhas": "SobrancelhaSeria"}, "OlhoVermelho"), ({"olhos": "OlhoQuadrado"}, "OlhoDourado"))], dist=5, esp=2.2, ty=1.7),
             grade(q, "pecas", [{"cabelo": "CabeloCurto1", "roupas": [r]} for r in ("RoupaCapuz1", "RoupaCapaCurta1", "RoupaCinto1", "RoupaOmbreira1")]
                   + [], esp=3.6)]
        L.montagem(f, "build/qa/pers3b/g_rostos_pecas.png", (0, 100, 1411, 520))
    finally:
        q.c.close()

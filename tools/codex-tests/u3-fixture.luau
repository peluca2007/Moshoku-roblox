-- Simula o layout real de ExtraCombate; nenhum serviço/Studio.
local function dimensao(a, b, c, d)
	return {X = {Scale = a, Offset = b}, Y = {Scale = c, Offset = d}}
end
local UDim2 = {new = dimensao, fromOffset = function(x,y) return dimensao(0,x,0,y) end}
local UDim = {new = function(s,o) return {Scale=s,Offset=o} end}
local Vector2 = {new = function(x,y) return {X=x,Y=y} end}
local Enum = {TextTruncate={None="None",AtEnd="AtEnd"},TextXAlignment={Right="Right",Left="Left"},TextYAlignment={Center="Center"},ApplyStrokeMode={Border="Border"}}
local function objeto(classe)
 local o={ClassName=classe,children={},signals={},Active=true}
 function o:IsA(c) return c==self.ClassName end
 function o:GetChildren() return self.children end
 function o:FindFirstChild(id) for _,v in self.children do if v.Name==id then return v end end end
 function o:FindFirstChildOfClass(c) for _,v in self.children do if v.ClassName==c then return v end end end
 function o:GetAttribute(k) return self[k] end
 function o:SetAttribute(k,v) self[k]=v end
 function o:GetPropertyChangedSignal(k)
  self.signals[k]=self.signals[k] or {}
  return {Connect=function(_,f) table.insert(self.signals[k],f) end}
 end
 function o:Destroy() self.destroyed=true end
 o.Activated={Connect=function(_,fn) o.click=fn end}
 return setmetatable(o,{__newindex=function(t,k,v)
  if k=="Parent" and v then table.insert(v.children,t) end
  rawset(t,k,v)
 end})
end
local Instance = {new = objeto}
local tema = {fontes={rotulo="rotulo"},tamanhos={rotulo=16},cores={ouro="ouro",painel="painel",textoEscuro="escuro",texto="texto",vinho="vinho",borda="borda",secundario="secundario"},transparencias={desabilitado=.35},raios={botao=6},espessuras={borda=1.5},toqueMinimo=44,FONTE_ICONE="icone",icone=function(n) return n end}
local componentes = {texto = function(p) return {Text=p.texto} end}
local Extra = (function()
-- U3_EXTRA_SOURCE
end)()
local function botao(nome, texto, ativo)
 local b=objeto("TextButton")
 b.Name,b.Text,b.Active,b.ZIndex=nome,texto,ativo,1
 b.Activated="comando original"
	return b
end
for _, largura in {319, 347, 640, 952} do
	local ataque=botao("Atacar_1","Atacar Goblin",true)
	local fuga=botao("Fugir","Fugir | 1 Ação",true)
	local cura=botao("Habilidade_Cura","Cura · 2 Ações/3 PM → Aliado · 32/32 PV",false)
	local defender=botao("Habilidade_Defender","Defender · 1 Ação",true)
	local lista={children={},GetChildren=function() return {ataque, cura, defender, fuga} end}
	local altura=Extra.acoes(lista,largura)
	assert(altura>=84,"canvas cobre as cartas")
	for _, b in {ataque,cura,defender,fuga} do
		assert(b.Size.X.Offset>=44 and b.Size.Y.Offset>=44,"toque mínimo físico")
		assert(b.Position.X.Offset>=0 and b.Position.X.Offset+b.Size.X.Offset<=largura,"sem corte horizontal")
		assert(b.Activated=="comando original","apresentação preserva callback")
	end
	assert(ataque.BackgroundColor3==tema.cores.ouro,"ação principal ouro")
	assert(defender.BackgroundColor3==tema.cores.painel,"defender utilitária secundária")
	assert(fuga.Position.Y.Offset>=ataque.Position.Y.Offset,"fuga separada depois das ações")
	assert(cura:FindFirstChild("NomeAcao").TextTransparency==tema.transparencias.desabilitado,"indisponivel apagado")
 for _, b in {ataque,cura,defender,fuga} do
  local nome,efeito,custo=b:FindFirstChild("NomeAcao"),b:FindFirstChild("EfeitoAcao"),b:FindFirstChild("Custo")
  assert(b.TextTransparency==1,"texto original nao duplica custo")
  assert(nome.Position.Y.Offset+nome.Size.Y.Offset<=efeito.Position.Y.Offset,"nome separado do efeito")
  assert(efeito.Position.Y.Offset+efeito.Size.Y.Offset<=custo.Position.Y.Offset,"custo nao intersecta texto")
  assert(custo.Position.Y.Offset+custo.Size.Y.Offset<=b.Size.Y.Offset,"custo dentro da carta")
  assert(not efeito.Text:find("Ação") and not efeito.Text:find("Ações"),"sem custo duplicado")
 end
 assert(cura:FindFirstChild("EfeitoAcao").Text:find("32/32 PV"),"preserva alvo e PV")
 cura.Text="Cura · 2 Ações/3 PM · novo alvo"
 for _,f in cura.signals.Text do f() end
 assert(cura:FindFirstChild("EfeitoAcao").Text=="novo alvo","atualiza selecao sem perder selo")
 local faixa=objeto("Frame")
 local mover=botao("Mover","Mover",true)
 local passar=botao("EncerrarTurno","Encerrar",true)
 local desistir=botao("Desistir","Render-se",true)
 desistir.Visible=true
 local acoes={ataque,cura,defender,fuga,mover}
 local listaMobile={children={},GetChildren=function() return acoes end}
 local grupo
 Extra.faixa(listaMobile,faixa,passar,desistir,largura,nil,function(g) grupo=g end)
 assert(not listaMobile.Visible,"faixa inicia compacta")
 for _,b in faixa:GetChildren() do
  assert(b.Size.Y.Offset>=44 and b.Size.X.Offset>=44,"toque da faixa")
  local rotulo=b:FindFirstChild("RotuloCompacto")
  assert(rotulo and rotulo.TextSize>=16 and rotulo.TextWrapped==false,"rótulo móvel de uma linha >=16")
  assert(b:FindFirstChild("IconeCompacto").TextSize>=28,"ícone grande")
  assert(b.Position.X.Offset+b.Size.X.Offset<=largura+0.01,"faixa sem rolagem")
 end
 assert(mover.Parent==faixa and defender.Parent==faixa and passar.Parent==faixa,"principais acessiveis sem rolar")
 assert(mover.Activated=="comando original" and defender.Activated=="comando original","callbacks reutilizados")
 faixa:FindFirstChild("AbrirHabilidades").click()
 assert(grupo=="habilidades" and cura.Visible and not ataque.Visible and desistir.Visible,"submenu habilidades e rendicao")
 for _,label in cura:GetChildren() do if label:IsA("TextLabel") then assert(label.TextSize>=16,"submenu móvel texto >=16") end end
 faixa:FindFirstChild("AbrirAtaques").click()
 assert(grupo=="ataque" and ataque.Visible and not cura.Visible,"lista de alvos")
 faixa:FindFirstChild("AbrirAtaques").click()
 assert(not listaMobile.Visible,"recolhe submenu")
 defender.Active=false
 for _,f in defender.signals.Active do f() end
 assert(defender.TextTransparency==1 and defender:FindFirstChild("RotuloCompacto").TextTransparency==tema.transparencias.desabilitado,"faixa aguarda sem texto duplicado")
end
print("Interface U3: simulação toque/layout/comandos ok (APIs falsas)")

local V = require(game:GetService("ReplicatedStorage").Shared.VozesNPCs)
local D = require(game:GetService("ReplicatedStorage").Shared.DublagemNPCs)
local function token(id, familia, pv)
	return { id = id, vozNPC = familia or "npc__goblin-batedor", pv = pv or 10, pvMax = 10 }
end
local function snap(tokens) return { combat = { active = true }, tokens = tokens } end
return {
	["identidade sonora fecha enum sem usar nomes ou stats"] = function(t)
		t.eq(V.familia("creature/lobo-cinzento"), "npc__lobo-cinzento")
		t.eq(V.familia("creature/segredo"), nil)
		t.eq(V.familia(nil), nil)
	end,
	["entradas nao repetem por snapshot ou ocultacao"] = function(t)
		local m, s = V.novo(), snap({token("g")})
		t.eq(#V.snapshot(m,s),1); t.eq(#V.snapshot(m,s),0)
		t.eq(#V.snapshot(m,snap({})),0); t.eq(#V.snapshot(m,s),0)
	end,
	["remocao nunca significa derrota"] = function(t)
		local m = V.novo(); V.snapshot(m,snap({token("g")}))
		t.eq(#V.snapshot(m,snap({})),0)
		local g=token("g"); g.derrotado=true
		local r=V.snapshot(m,snap({g})); t.eq(#r,1); t.eq(r[1].prioridade,5)
		t.eq(#V.snapshot(m,snap({g})),0)
	end,
	["PV secreto nao dispara pouca vida"] = function(t)
		local m=V.novo(); local g=token("g"); g.pv=nil; g.pvMax=nil
		V.snapshot(m,snap({g})); t.eq(#V.snapshot(m,snap({g})),0)
		g.pv,g.pvMax=2,10; local r=V.snapshot(m,snap({g})); t.eq(#r,1)
		t.ok(string.find(r[1].prefixo,"pouca%-vida")~=nil); t.eq(#V.snapshot(m,snap({g})),0)
	end,
	["recibo de dano filtrado so reage a alvos visiveis uma vez"] = function(t)
		local m,s=V.novo(),snap({token("g")})
		local r={alvos={{id="g",dano=4,critico=true},{id="g",dano=4},{id="oculto",dano=10}}}
		local out=V.efeito(m,s,r);t.eq(#out,1);t.ok(string.find(out[1].prefixo,"dor%-forte")~=nil)
		t.eq(#V.efeito(m,s,r),0)
	end,
	["falha cura e ausencia de dano nao causam dor"] = function(t)
		t.eq(#V.efeito(V.novo(),snap({token("g")}),{alvos={{id="g",dano=0,acertou=false},{id="g",cura=4}}}),0)
	end,
	["especial nao duplica ataque generico"] = function(t)
		local s=snap({token("b","boss__treant-anciao")})
		t.eq(#V.efeito(V.novo(),s,{casterId="b",habilidadeId="criatura/ataque",estilo="raizes",alvos={}}),0)
		t.eq(#V.efeito(V.novo(),s,{casterId="b",habilidadeId="criatura/ataque",alvos={}}),1)
	end,
	["fase aviso e execucao so usam chefe publico confirmado"] = function(t)
		local s=snap({token("b","boss__treant-anciao")}); local m=V.novo()
		s.encontro={chefe={id="b",fase=1}};V.snapshot(m,s)
		s.encontro.chefe.fase=2; s.encontro.chefe.aviso={id=8,fase=2}
		t.eq(#V.snapshot(m,s),2);t.eq(#V.snapshot(m,s),0)
		local d={id="b",aviso={id=8,fase=2},agiu=false};t.eq(#V.especial(m,s,d),0)
		d.agiu=true;t.eq(#V.especial(m,s,d),1);t.eq(#V.especial(m,s,d),0)
		s.tokens={};d.aviso.id=9;t.eq(#V.especial(m,s,d),0)
	end,
	["fora do combate nao planeja voz"] = function(t)
		local s=snap({token("g")});s.combat.active=false
		t.eq(#V.snapshot(V.novo(),s),0);t.eq(#V.efeito(V.novo(),s,{casterId="g",habilidadeId="criatura/ataque"}),0)
	end,
	["catalogo possui56 IDs e9 reusos reais do lobo no urso"] = function(t)
		local n=0;for _,f in D do n+=1;t.ok(string.match(f.id,"^rbxassetid://[1-9]%d*$")~=nil);t.ok(f.segundos>0) end;t.eq(n,56)
		t.eq(D["npc__urso-de-presas-vermelhas__ataque__01"].id,D["npc__lobo-cinzento__ataque__01"].id)
		t.eq(D["npc__urso-de-presas-vermelhas__entrada__01"].id,D["npc__lobo-cinzento__ameaca__01"].id)
	end,
}

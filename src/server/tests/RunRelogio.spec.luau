local Shared = game:GetService("ReplicatedStorage").Shared
local Run = require(Shared.Regras.Run)
local R = require(Shared.Regras.RunRelogio)
local Save = require(Shared.Regras.RunSave)
local function nova() return Run.nova({ jogadores={11}, objetivo={id="selo",prazoDias=12} }) end
return {
 ["480 segundos completam um dia e combate pausa"] = function(t)
  local a = nova()
  local b = R.avancar(a,240,false)
  t.eq(b.dia,0.5); t.eq(a.dia,0)
  t.eq(R.visao(b).periodo,"tarde")
  t.eq(R.visao(a).hora,6)
  local c = R.avancar(b,100,true); t.eq(c,b)
  c = R.avancar(b,240,false); t.eq(c.dia,1);t.eq(R.visao(c).dia,2)
 end,
 ["descanso curto soma horas longo e treino pulam uma unica manha"] = function(t)
  local a=R.avancar(nova(),120,false)
  a=R.descansar(a,"curto");t.eq(a.dia,1/3)
  a=R.descansar(a,"longo");t.eq(a.dia,1)
  a=R.descansar(a,"treino");t.eq(a.dia,2)
 end,
 ["prazo expira na hora limite e estado continuo persiste"] = function(t)
  local salto=Run.gastarDias(nova(),12)
  t.eq(salto.objetivo.status,"expirado")
  local a=R.avancar(nova(),5759,false);t.eq(a.objetivo.status,"ativo")
  a=R.avancar(a,1,false);t.eq(a.objetivo.status,"expirado")
  a=R.avancar(a,1.23,false)
  t.eq(Run.estadoValido(a),true)
  local dado=Save.serializar(a,{});local b=Save.restaurar(dado)
  t.eq(b.dia,a.dia);t.eq(R.visao(b).hora,R.visao(a).hora)
 end,
 ["relogio recusa tempo corrompido e fim congela"] = function(t)
  local a=nova();t.eq(R.avancar(a,-1),nil);t.eq(R.avancar(a,math.huge),nil);t.eq(R.avancar(a,0/0),nil)
  a=Run.encerrarComFinal(a,"fim");t.eq(R.avancar(a,480),a)
 end,
}

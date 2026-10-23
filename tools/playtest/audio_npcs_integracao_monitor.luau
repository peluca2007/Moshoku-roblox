-- Fixture temporária: observa sons reais e verifica carregamento sem sobrepor47 falas.
local Http = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local dados = { pronto = false, terminou = false, carregados = {}, falhas = {}, vozes = {} }
local function salvar() script:SetAttribute("Resultado", Http:JSONEncode(dados)) end
SoundService.ChildAdded:Connect(function(s)
	if not s:IsA("Sound") or not string.match(s.Name,"^VozNPC_") then return end
	task.delay(.12,function()
		table.insert(dados.vozes,{nome=s.Name,id=s.SoundId,carregado=s.IsLoaded,tocando=s.IsPlaying,grupo=s.SoundGroup and s.SoundGroup.Name})
		salvar()
	end)
end)
task.spawn(function()
	local D = require(game.ReplicatedStorage.Shared.DublagemNPCs)
	local CP = game:GetService("ContentProvider")
	local unicos = {}
	for chave,f in D do if not unicos[f.id] then unicos[f.id]=chave end end
	dados.pronto=true; salvar()
	local concluidos,total=0,0;for _ in unicos do total+=1 end
	for id,chave in unicos do
		task.spawn(function()
			local som=Instance.new("Sound");som.Name="BancadaNPC";som.SoundId=id;som.Volume=0;som.Parent=SoundService
			local ok,err=pcall(function() CP:PreloadAsync({som}) end)
			if ok and som.IsLoaded and som.TimeLength>0 then
				som:Play();task.wait(.08)
				table.insert(dados.carregados,{chave=chave,id=id,duracao=som.TimeLength,tocando=som.IsPlaying})
			else table.insert(dados.falhas,{chave=chave,id=id,erro=tostring(err)}) end
			som:Destroy();concluidos+=1;dados.terminou=concluidos==total;salvar()
		end)
		task.wait(.06)
	end
end)

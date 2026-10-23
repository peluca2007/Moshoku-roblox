-- Sobe e aproxima na própria mesa. A arena só aparece depois do corte escuro.
local E=require(game.ReplicatedStorage.Shared.SalaEspaco)
local T={}
function T.new(pg)
	local g=Instance.new("ScreenGui");g.Name="TransicaoSala";g.IgnoreGuiInset=true;g.DisplayOrder=200;g.ResetOnSpawn=false;g.Parent=pg
	local tela=Instance.new("Frame");tela.Size=UDim2.fromScale(1,1);tela.BackgroundColor3=Color3.fromRGB(9,12,13);tela.BorderSizePixel=0;tela.BackgroundTransparency=1;tela.Visible=false;tela.Parent=g
	local inicio,origem,revelar=nil,nil,nil
	local api={}
	local function suave(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
	function api.atualizar(transicao,lobby,camera)
		if transicao then
			if inicio~=transicao.inicio then inicio=transicao.inicio;origem=camera.CFrame;revelar=nil end
			local t=math.clamp((workspace:GetServerTimeNow()-inicio)/2.4,0,1)
			local alvo=E.MESA+Vector3.new(0,.7,0)
			local alto=CFrame.lookAt(alvo+Vector3.new(0,9,-5),alvo)
			local perto=CFrame.lookAt(alvo+Vector3.new(0,5.6,-2.2),alvo)
			camera.CameraType=Enum.CameraType.Scriptable
			camera.CFrame=if t<.58 then origem:Lerp(alto,suave(t/.58)) else alto:Lerp(perto,suave((t-.58)/.32))
			tela.Visible=true;tela.BackgroundTransparency=1-suave((t-.76)/.2)
		elseif inicio then
			if not revelar then revelar=os.clock() end
			local t=suave((os.clock()-revelar)/.7);tela.Visible=t<1;tela.BackgroundTransparency=t
			if lobby then camera.CameraType=Enum.CameraType.Custom end
			if t>=1 then inicio=nil;origem=nil;revelar=nil end
		end
	end
	return api
end
return T

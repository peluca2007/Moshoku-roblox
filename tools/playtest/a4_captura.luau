-- Enquadramento temporário para inspeção artística. Somente cliente em Play.
local RunService=game:GetService("RunService")
local Client=game.Players.LocalPlayer.PlayerScripts.Client
local Coreografia=require(Client.Coreografia)
local P=require(game.ReplicatedStorage.Shared.MesaProtocol)
local pasta=Instance.new("Folder");pasta.Name="A4CapturaTemporaria";pasta.Parent=workspace
local a,b=P.cellCenter(8,10)+Vector3.yAxis*3,P.cellCenter(11,10)+Vector3.yAxis*3
local api=Coreografia.start({},pasta,function(_,id) return if id=="a" then a else b end)
local camera=workspace.CurrentCamera;local cf,tipo=camera.CFrame,camera.CameraType
local telas={}
for _,gui in game.Players.LocalPlayer.PlayerGui:GetChildren() do
 if gui:IsA("ScreenGui") then telas[gui]=gui.Enabled;gui.Enabled=false end
end
RunService:BindToRenderStep("A4Captura",Enum.RenderPriority.Camera.Value+10,function()
 camera.CameraType=Enum.CameraType.Scriptable
 camera.CFrame=CFrame.lookAt(Vector3.new(16,27,29),Vector3.new(-5,2,-2))
end)
task.spawn(function()
 for _=1,12 do
  api.tocar({habilidadeId="ability/agua/Principiante/impacto-de-gelo",casterId="a",origem={8,10},alvos={{id="b",acertou=true}}})
  task.wait(1.8)
 end
 api.destruir();pasta:Destroy();RunService:UnbindFromRenderStep("A4Captura")
 camera.CameraType,camera.CFrame=tipo,cf
 for gui,enabled in telas do if gui.Parent then gui.Enabled=enabled end end
end)
return "Prévia temporária iniciada; câmera/interface restauradas em 22 segundos ou ao parar Play."

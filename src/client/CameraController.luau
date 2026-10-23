local CameraController = {}
function CameraController.battle(camera: Camera, origin: Vector3)
 camera.CameraType=Enum.CameraType.Scriptable
 camera.CFrame=CFrame.lookAt(origin+Vector3.new(0,65,28),origin)
end
function CameraController.explore(camera: Camera, character: Model?)
 camera.CameraType=Enum.CameraType.Custom
 if character then camera.CameraSubject=character:FindFirstChildOfClass("Humanoid") end
end
return CameraController

-- Geometria apenas da sala social, separada da arena de combate.
local E={CENTRO=Vector3.new(250,0,0),MESA=Vector3.new(250,3,0)}
function E.lugar(i)
	local pos
	if i==1 then pos=Vector3.new(250,2,-12)
	elseif i==10 then pos=Vector3.new(250,2,12)
	else local n=i-2;pos=Vector3.new(250+(if n%2==0 then -8 else 8),2,-7+math.floor(n/2)*4.5) end
	return CFrame.lookAt(pos,Vector3.new(250,pos.Y,0))
end
return E

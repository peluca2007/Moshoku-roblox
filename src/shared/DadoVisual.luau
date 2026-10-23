-- Dados nativos: seis faces coerentes, sem scripts/assets executáveis externos.
local D={}
local pontos={{{.5,.5}},{{.25,.25},{.75,.75}},{{.25,.25},{.5,.5},{.75,.75}},{{.25,.25},{.75,.25},{.25,.75},{.75,.75}},{{.25,.25},{.75,.25},{.5,.5},{.25,.75},{.75,.75}},{{.25,.22},{.75,.22},{.25,.5},{.75,.5},{.25,.78},{.75,.78}}}
local faces={Enum.NormalId.Top,Enum.NormalId.Front,Enum.NormalId.Left,Enum.NormalId.Right,Enum.NormalId.Back,Enum.NormalId.Bottom}
function D.criar(parent,i)
	local p=Instance.new("Part");p.Name="Dado"..i;p.Size=Vector3.one*.48;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(241,228,196);p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	p.CustomPhysicalProperties=PhysicalProperties.new(.8,.45,.42,1,1)
	local cores={Color3.fromRGB(232,215,177),Color3.fromRGB(43,83,70),Color3.fromRGB(113,52,51)};p.Color=cores[i] or cores[1]
	for n,face in faces do
		local g=Instance.new("SurfaceGui");g.Name="Face"..n;g.Face=face;g.CanvasSize=Vector2.new(100,100);g.LightInfluence=.2;g.Parent=p
		local fundo=Instance.new("Frame");fundo.Size=UDim2.fromScale(.9,.9);fundo.Position=UDim2.fromScale(.05,.05);fundo.BackgroundTransparency=1;fundo.Parent=g
		local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.15,0);c.Parent=fundo
		local borda=Instance.new("UIStroke");borda.Color=Color3.fromRGB(185,153,101);borda.Transparency=.5;borda.Thickness=2;borda.Parent=fundo
		for _,pos in pontos[n] do local dot=Instance.new("Frame");dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=UDim2.fromScale(pos[1],pos[2]);dot.Size=UDim2.fromScale(.17,.17);dot.BackgroundColor3=if i==1 then Color3.fromRGB(48,39,32) else Color3.fromRGB(242,218,166);dot.BorderSizePixel=0;dot.Parent=g;local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=dot end
	end
	p.Parent=parent;return p
end
function D.rotacao(n)
	return ({CFrame.identity,CFrame.Angles(math.pi/2,0,0),CFrame.Angles(0,0,-math.pi/2),CFrame.Angles(0,0,math.pi/2),CFrame.Angles(-math.pi/2,0,0),CFrame.Angles(math.pi,0,0)})[n]
end
return D

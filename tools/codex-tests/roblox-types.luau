-- Subconjunto usado pelos specs puros. Não substitui os tipos do motor Roblox.
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
vectorMeta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vectorMeta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

local Color3 = {}
local colorMeta = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, colorMeta)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
colorMeta.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

return { Vector3 = Vector3, Color3 = Color3 }

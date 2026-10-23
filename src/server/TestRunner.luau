-- Executa módulos "*.spec" de uma pasta e imprime o resultado no Output do Studio.
-- Formato de um spec: módulo que devolve { ["descrição"] = function(t) ... end }.
-- t.eq(atual, esperado, msg?), t.ok(condição, msg?), t.fails(função, msg?).
local TestRunner = {}

local function describe(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local assertions = {
	eq = function(actual: any, expected: any, message: string?)
		if actual ~= expected then
			error(string.format("%sesperado %s, obtido %s", if message then message .. ": " else "", describe(expected), describe(actual)), 2)
		end
	end,
	ok = function(condition: any, message: string?)
		if not condition then
			error(message or "condição falsa", 2)
		end
	end,
	fails = function(callback: () -> (), message: string?)
		if pcall(callback) then
			error(message or "era esperado um erro", 2)
		end
	end,
}

function TestRunner.run(folder: Instance): (number, number)
	local passed, failed = 0, 0
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") and string.match(module.Name, "%.spec$") then
			local loaded, spec = pcall(require, module)
			if not loaded or type(spec) ~= "table" then
				failed += 1
				warn(string.format("[Testes] %s não carregou: %s", module.Name, tostring(spec)))
				continue
			end
			for name, test in spec do
				local ok, failure = pcall(test, assertions)
				if ok then
					passed += 1
				else
					failed += 1
					warn(string.format("[Testes] FALHA %s › %s: %s", module.Name, tostring(name), tostring(failure)))
				end
			end
		end
	end
	local summary = string.format("[Testes] %d ok, %d falha(s)", passed, failed)
	if failed > 0 then
		warn(summary)
	else
		print(summary)
	end
	return passed, failed
end

return TestRunner

-- Tema único V2. Dados puros separados somente para o harness CLI existente.
-- Fontes/glifos: revisão externa no Studio, evidência ui-v1/91 (16/10/2026).
local Shared = game:GetService("ReplicatedStorage").Shared
local T = table.clone(require(Shared.UITemaDados))
local Estilo = require(Shared.Estilo)
T.arvore = Estilo.arvore -- identidade canônica, sem duplicar cores.
T.FONTE_ICONE = Font.fromEnum(Enum.Font.Garamond)
T.fontes = {
	titulo = Font.fromEnum(Enum.Font.Bodoni),
	subtitulo = Font.fromEnum(Enum.Font.Garamond),
	reserva = T.FONTE_ICONE,
	icone = T.FONTE_ICONE,
	corpo = Font.fromName(T.familias.corpo),
	italico = Font.fromName(T.familias.corpo, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	rotulo = Font.fromName(T.familias.rotulo, Enum.FontWeight.SemiBold),
	numero = Font.fromName(T.familias.numero),
}
return T

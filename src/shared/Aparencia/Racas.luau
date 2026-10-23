local POR_ID={}
local ids={"humano","elfo","anao","hobbit","raca-fera","celestial","oceano","migurd","superd","ogro","demonio-imortal","dragao"}
for _, id in ids do POR_ID["race/"..id]={ escala={altura=1,largura=1,profundidade=1,cabeca=1},paleta={"PeleClara","PeleMedia","PeleEscura","PeleOliva"},coresOlho={"OlhoCastanho","OlhoAzul","OlhoVerde","OlhoTurquesa","OlhoVioleta","OlhoVermelho","OlhoDourado","OlhoNegro"},coresCabelo={"CabeloPreto","CabeloCastanho","CabeloLoiro","CabeloRuivo","CabeloBranco","CabeloAzul","CabeloVerde","CabeloRosa"},coresCamisa={"CamisaVermelha","CamisaAzul","CamisaVerde","CamisaPreta","CamisaBranca","CamisaRoxa"},coresCalca={"CalcaMarrom","CalcaPreta","CalcaAzul","CalcaCinza"},obrigatorias={},opcionais={}} end
POR_ID["race/elfo"].obrigatorias={"OrelhasElficas"}; POR_ID["race/raca-fera"].obrigatorias={"OrelhasBestiais"}; POR_ID["race/superd"].obrigatorias={"CaudaSuperd"}; POR_ID["race/celestial"].obrigatorias={"AsasCelestial"}
POR_ID["race/migurd"].coresOlho={"OlhoAzul"}; POR_ID["race/migurd"].coresCabelo={"CabeloAzul"}
POR_ID["race/superd"].coresCabelo={"CabeloVerde"}; POR_ID["race/superd"].paleta={"PeleClara"}
-- Chifres são opção cosmética de Ogro (adaptação explícita, não afirmação do livro).
POR_ID["race/ogro"].opcionais={"ChifresOgro"}
POR_ID["race/migurd"].escala={altura=0.9,largura=0.92,profundidade=0.92,cabeca=1.02}
POR_ID["race/raca-fera"].escala={altura=1.03,largura=1.06,profundidade=1.04,cabeca=1}
-- Oceano: o livro não especifica cor de pele/forma, preserva a diversidade humana.

POR_ID["race/anao"].escala={altura=0.85,largura=1.12,profundidade=1.1,cabeca=0.95}; POR_ID["race/hobbit"].escala={altura=0.78,largura=0.9,profundidade=0.9,cabeca=1.05}; POR_ID["race/elfo"].escala={altura=1.04,largura=0.92,profundidade=0.92,cabeca=1}
POR_ID["race/ogro"].escala={altura=1.18,largura=1.15,profundidade=1.12,cabeca=1.08}; POR_ID["race/demonio-imortal"].escala={altura=1.04,largura=1.02,profundidade=1.02,cabeca=1}
POR_ID["race/demonio-imortal"].paleta={"PeleAzeviche"}; POR_ID["race/dragao"].escala={altura=1.12,largura=1.08,profundidade=1.08,cabeca=1.05}
-- Dragão (Ryuzoku) de Mushoku Tensei vive em "corpo de gente" (livro): aparência humana, sem chifres
-- nem cauda; cabelo prateado e olhos dourados como Orsted/Perugius (pedido do Pedro, 16/10/2026).
POR_ID["race/dragao"].coresCabelo={"CabeloPrata","CabeloBranco"}; POR_ID["race/dragao"].coresOlho={"OlhoDourado"}; POR_ID["race/dragao"].paleta={"PeleClara"}
return { POR_ID=POR_ID }

import pers3b_lib as L, pers3b_grade as G
q=L.Qa(); q.cenario="grade"
it=[{"cabelo":"CabeloCurto1","roupas":[r]} for r in ("RoupaCapuz1","RoupaCapaCurta1","RoupaCinto1","RoupaOmbreira1")]
f=[G.grade(q,"pc%d"%a,it,esp=4.6,ang=a,ty=0.5,dist=16) for a in (25,160)]
L.montagem(f,"build/qa/pers3b/g_pecas.png",(0,60,1411,560)); q.c.close()

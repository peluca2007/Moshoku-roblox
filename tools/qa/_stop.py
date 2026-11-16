from qa_lib import Qa
q=Qa()
try: q.play_parar()
except Exception as e: print(e)
q.c.close()

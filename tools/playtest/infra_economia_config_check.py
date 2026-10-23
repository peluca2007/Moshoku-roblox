import json, pathlib, subprocess, threading
root = pathlib.Path.cwd()
p = subprocess.Popen(['codex', 'app-server', '--strict-config', '--stdio'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', errors='replace')
timer = threading.Timer(25, p.kill)
timer.start()
def send(obj):
    p.stdin.write(json.dumps(obj) + '\n'); p.stdin.flush()
def response(req_id):
    for line in p.stdout:
        try: msg = json.loads(line)
        except json.JSONDecodeError: continue
        if msg.get('id') == req_id: return msg
    raise RuntimeError('app-server terminou antes da resposta: ' + p.stderr.read()[-1200:])
try:
    send({'id':1, 'method':'initialize', 'params':{'clientInfo':{'name':'moshoku_config_check','version':'1.0'}}})
    first=response(1)
    if 'error' in first: raise RuntimeError(str(first['error']))
    send({'method':'initialized'})
    send({'id':2,'method':'config/read','params':{'includeLayers':False,'cwd':str(root)}})
    result=response(2)
    if 'error' in result: raise RuntimeError(str(result['error']))
    config=result['result']['config']
    print(json.dumps({'model':config.get('model'),'model_reasoning_effort':config.get('model_reasoning_effort'),'agents':config.get('agents')},ensure_ascii=False,indent=2))
finally:
    p.stdin.close()
    try: p.wait(timeout=3)
    except subprocess.TimeoutExpired: p.kill(); p.wait()
    timer.cancel()

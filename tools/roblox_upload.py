"""Envia um arquivo (FBX/GLB como Model, PNG como Decal) à conta do Pedro pela Open Cloud
(Assets API) e imprime o assetId. Só biblioteca padrão.

Uso:
  python tools/roblox_upload.py build/blender/Rocha3.fbx --nome "Rocha3" [--tipo Model|Decal]

Chave: arquivo apontado por MOSHOKU_ROBLOX_KEY_FILE ou ~/.moshoku/roblox_api_key.txt (fora do
projeto e do OneDrive). A chave nunca é impressa nem gravada. Dono: usuário MOSHOKU_ROBLOX_USER
(padrão 2287856135, o do Pedro). O asset nasce privado, só para a conta do dono.
"""
import argparse
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1"
USUARIO_PADRAO = "2287856135"


def ler_chave():
    caminho = os.environ.get("MOSHOKU_ROBLOX_KEY_FILE") or os.path.expanduser("~/.moshoku/roblox_api_key.txt")
    try:
        with open(caminho, encoding="utf-8") as f:
            chave = f.read().strip()
    except OSError:
        sys.exit(f"Chave não encontrada em {caminho}.")
    if not chave:
        sys.exit(f"Arquivo da chave vazio: {caminho}.")
    return chave


def requisitar(metodo, url, chave, corpo=None, cabecalhos=None):
    cab = {"x-api-key": chave}
    cab.update(cabecalhos or {})
    pedido = urllib.request.Request(url, data=corpo, method=metodo, headers=cab)
    try:
        with urllib.request.urlopen(pedido, timeout=60) as r:
            return r.status, json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        texto = e.read().decode("utf-8", "replace")[:600]
        return e.code, {"erro": texto}


def multipart(campos, arquivo_nome, arquivo_bytes, arquivo_tipo):
    limite = uuid.uuid4().hex
    partes = []
    for nome, valor in campos.items():
        partes.append(
            (f"--{limite}\r\nContent-Disposition: form-data; name=\"{nome}\"\r\n"
             f"Content-Type: application/json\r\n\r\n{valor}\r\n").encode("utf-8"))
    partes.append(
        (f"--{limite}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{arquivo_nome}\"\r\n"
         f"Content-Type: {arquivo_tipo}\r\n\r\n").encode("utf-8"))
    partes.append(arquivo_bytes)
    partes.append(f"\r\n--{limite}--\r\n".encode("utf-8"))
    return b"".join(partes), f"multipart/form-data; boundary={limite}"


def enviar(arquivo, nome, tipo="Model", descricao="Gerado por script (Blender) para o projeto Moshoku"):
    """Envia `arquivo` e devolve o assetId (str). Encerra o programa com mensagem em caso de erro.
    MOSHOKU_VIA_STUDIO=1 (ou --via-studio nos scripts) usa a rota do Studio em vez da chave."""
    if os.environ.get("MOSHOKU_VIA_STUDIO") == "1":
        return enviar_via_studio(arquivo, nome, tipo, descricao)
    chave = ler_chave()
    usuario = os.environ.get("MOSHOKU_ROBLOX_USER", USUARIO_PADRAO)
    with open(arquivo, "rb") as f:
        dados = f.read()
    pedido = {
        "assetType": tipo,
        "displayName": nome,
        "description": descricao,
        "creationContext": {"creator": {"userId": usuario}},
    }
    mime = mimetypes.guess_type(arquivo)[0] or "application/octet-stream"
    if arquivo.lower().endswith(".fbx"):
        mime = "model/fbx"
    corpo, ctype = multipart({"request": json.dumps(pedido)}, os.path.basename(arquivo), dados, mime)
    status, resposta = requisitar("POST", f"{API}/assets", chave, corpo, {"Content-Type": ctype})
    if status >= 300:
        sys.exit(f"Upload recusado (HTTP {status}): {resposta.get('erro', resposta)}")
    operacao = resposta.get("path") or resposta.get("operationId")
    if not operacao:
        sys.exit(f"Resposta inesperada: {resposta}")
    url_op = f"{API}/{operacao}" if operacao.startswith("operations/") else f"{API}/operations/{operacao}"
    for _ in range(60):
        time.sleep(2)
        status, op = requisitar("GET", url_op, chave)
        if status >= 300:
            sys.exit(f"Falha ao consultar a operação (HTTP {status}): {op.get('erro', op)}")
        if op.get("done"):
            if "error" in op:
                sys.exit(f"Upload falhou: {op['error']}")
            return str(op.get("response", {}).get("assetId"))
    sys.exit("Tempo esgotado esperando a moderação/processamento do asset.")


def enviar_via_studio(arquivo, nome, tipo="Model", descricao="Gerado por script (Blender) para o projeto Moshoku"):
    """Mesmo envio, sem chave: `open_cloud_invoke` do MCP do Studio (permissões do Assistant, escopos asset:read/write).
    Exige que a pasta do arquivo conste em Assistant -> MCP Permissions -> pastas aprovadas para upload (o Pedro
    configura; o Studio recusa arquivos fora delas e manda não copiar para contornar). Devolve o assetId (str)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from studio_mcp import Client
    usuario = os.environ.get("MOSHOKU_ROBLOX_USER", USUARIO_PADRAO)
    pedido = {"assetType": tipo, "displayName": nome, "description": descricao,
              "creationContext": {"creator": {"userId": usuario}}}
    mime = "model/fbx" if arquivo.lower().endswith(".fbx") else (mimetypes.guess_type(arquivo)[0] or "application/octet-stream")
    c = Client()
    try:
        studio = c.studio_id()
        r = c.call("open_cloud_invoke", {
            "studio_id": studio, "endpoint": "/assets/v1/assets", "method": "POST",
            "scopes": ["asset:read", "asset:write"], "body": json.dumps({"request": json.dumps(pedido)}),
            "files": [{"name": "fileContent", "path": os.path.abspath(arquivo), "contentType": mime}]})
        if r.get("isError"):
            sys.exit("Upload pelo Studio recusado: " + r["text"][:600])
        try:
            op = json.loads(r["text"][r["text"].index("{"):])
        except ValueError:
            sys.exit("Resposta inesperada do Studio: " + r["text"][:600])
        caminho = op.get("path") or "operations/" + str(op.get("operationId"))
        for _ in range(60):
            time.sleep(2)
            g = c.call("open_cloud_invoke", {"studio_id": studio, "endpoint": f"/assets/v1/{caminho}",
                                             "method": "GET", "scopes": ["asset:read"]})
            if g.get("isError"):
                sys.exit("Falha ao consultar a operação: " + g["text"][:600])
            try:
                corpo = json.loads(g["text"][g["text"].index("{"):])
            except ValueError:
                continue
            if corpo.get("done"):
                if "error" in corpo:
                    sys.exit(f"Upload falhou: {corpo['error']}")
                return str(corpo.get("response", {}).get("assetId"))
        sys.exit("Tempo esgotado esperando o asset.")
    finally:
        c.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivo")
    ap.add_argument("--nome", required=True)
    ap.add_argument("--tipo", default="Model", choices=["Model", "Decal"])
    ap.add_argument("--descricao", default="Gerado por script (Blender) para o projeto Moshoku")
    args = ap.parse_args()
    print(json.dumps({"assetId": enviar(args.arquivo, args.nome, args.tipo, args.descricao), "nome": args.nome}))


if __name__ == "__main__":
    main()

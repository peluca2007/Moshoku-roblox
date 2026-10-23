"""Prepara cópias WAV das vozes entregues, sem upload nem alteração dos originais.

Uso: python tools/dublagem/preparar_npcs.py --ffmpeg CAMINHO
FFmpeg pode estar no PATH. Não instala programas. Saída gerada: assets/vozes-npcs.
Reaproveitamentos autorizados por Pedro: nove sons do urso podem vir do lobo.
"""
import argparse
import array
import csv
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RATE = 44100
ALIASES = {
    "entrada__01": "ameaca__01",
    "ameaca__01": "alerta__01",
    "ataque__01": "ataque__01",
    "ataque__02": "ataque__02",
    "dor-leve__01": "dor-leve__01",
    "dor-leve__02": "dor-leve__02",
    "dor-forte__01": "dor-forte__01",
    "pouca-vida__01": "pouca-vida__01",
    "derrota__01": "derrota__01",
}


def roteiro():
    text = (ROOT / "docs/DUBLAGEM_NPCS.md").read_text(encoding="utf-8")
    expected = {}
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cols = [c.strip() for c in line.split("|")[1:-1]]
        key = cols[0].strip("`").removesuffix(".ogg")
        if key in expected:
            raise ValueError("Chave duplicada no roteiro: " + key)
        expected[key] = {"alvo": float(cols[-2].replace(",", ".")),
                         "maximo": float(cols[-1].replace(",", "."))}
    if not expected:
        raise ValueError("Roteiro sem entradas")
    return expected


def chave(name):
    # Corrige apenas na identificação/cópia: backticks e .og/.ogg antes de .m4a.
    clean = name.replace("`", "").lower()
    clean = re.sub(r"\.(?:m4a|ogg|wav|mp3|flac)$", "", clean)
    clean = re.sub(r"\.ogg?$", "", clean)
    if not re.fullmatch(r"(?:npc|boss)__[a-z0-9-]+__[a-z0-9-]+__\d{2}", clean):
        raise ValueError("Nome de áudio não reconhecido: " + name)
    return clean


def cortar_bordas(samples):
    """Só bordas abaixo de -50 dBFS RMS, com margem de150ms; sem cortes internos."""
    frame = RATE // 100
    threshold = 32768 * 10 ** (-50 / 20)
    active = []
    for start in range(0, len(samples), frame):
        chunk = samples[start:start + frame]
        rms = math.sqrt(sum(v * v for v in chunk) / max(1, len(chunk)))
        if rms > threshold:
            active.append(start)
    if not active:
        raise ValueError("Áudio sem sinal acima do limiar de revisão")
    margin = round(RATE * .15)
    first = max(0, active[0] - margin)
    last = min(len(samples), active[-1] + frame + margin)
    return samples[first:last], first, len(samples) - last


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.ffmpeg:
        parser.error("Informe --ffmpeg; não é instalado automaticamente")
    expected = roteiro()
    source = ROOT / "audios"
    out = ROOT / "assets/vozes-npcs"
    if not out.resolve().is_relative_to((ROOT / "assets").resolve()):
        raise ValueError("Saída precisa permanecer em assets")
    inputs = {}
    for file in sorted(source.iterdir()):
        if not file.is_file() or file.suffix.lower() not in {".m4a", ".ogg", ".wav", ".mp3", ".flac"}:
            continue
        key = chave(file.name)
        if key not in expected or key in inputs:
            raise ValueError("Chave desconhecida/duplicada: " + key)
        inputs[key] = file
    if not inputs:
        raise ValueError("Nenhum áudio encontrado")

    # Decodificar todos antes de gravar evita deixar relatório parcialmente novo em falhas.
    prepared = {}
    for key, file in inputs.items():
        result = subprocess.run([args.ffmpeg, "-v", "error", "-nostdin", "-i", str(file),
            "-map", "0:a:0", "-vn", "-sn", "-dn", "-ac", "1", "-ar", str(RATE),
            "-c:a", "pcm_s16le", "-f", "s16le", "pipe:1"], capture_output=True, check=True)
        samples = array.array("h", result.stdout)
        if sys.byteorder != "little":
            samples.byteswap()
        original_count = len(samples)
        trimmed, before, after = cortar_bordas(samples)
        peak = max(abs(v) for v in trimmed)
        clipped = sum(abs(v) >= 32760 for v in trimmed)
        pcm = array.array("h", trimmed)
        if sys.byteorder != "little":
            pcm.byteswap()
        prepared[key] = (pcm.tobytes(), {
            "original": file.relative_to(ROOT).as_posix(),
            "sha256_original": hashlib.sha256(file.read_bytes()).hexdigest(),
            "arquivo": "arquivos/" + key + ".wav",
            "segundos_original": round(original_count / RATE, 3),
            "segundos": round(len(trimmed) / RATE, 3),
            "corte_inicio_s": round(before / RATE, 3), "corte_fim_s": round(after / RATE, 3),
            "pico_dbfs": round(20 * math.log10(peak / 32768), 2),
            "amostras_proximas_limite": clipped,
            "ganho_db": 0, "amostragem_hz": RATE, "canais": 1, "bits": 16,
        })

    entries, missing, warnings = {}, [], []
    for key, times in expected.items():
        used = key
        if used not in prepared and key.startswith("npc__urso-de-presas-vermelhas__"):
            situation = key.removeprefix("npc__urso-de-presas-vermelhas__")
            if situation in ALIASES:
                used = "npc__lobo-cinzento__" + ALIASES[situation]
        if used not in prepared:
            missing.append(key)
            continue
        item = prepared[used][1]
        entries[key] = {"gravacao": used, "arquivo": item["arquivo"],
                        "segundos": item["segundos"], "reutilizado": used != key, **times}
        if item["segundos"] > times["maximo"]:
            warnings.append({"chave": key, "tipo": "acima_duracao_sugerida", "segundos": item["segundos"], "maximo": times["maximo"]})
    if missing:
        raise ValueError("Entradas sem gravação/reuso: " + ", ".join(missing))

    # Uma nova preparação não pode apagar IDs que alguém preencheu na planilha.
    ids = {}
    csv_path = out / "importacao.csv"
    if csv_path.exists():
        with csv_path.open(encoding="utf-8-sig", newline="") as file:
            reader = csv.DictReader(file)
            if not reader.fieldnames or not {"chave", "id_roblox"}.issubset(reader.fieldnames):
                raise ValueError("CSV existente exige colunas chave e id_roblox separadas por vírgula")
            if len(set(reader.fieldnames)) != len(reader.fieldnames):
                raise ValueError("Cabeçalho duplicado no CSV existente; arquivo preservado")
            for row in reader:
                key = row.get("chave", "")
                if not key or not key.strip() or None in row or row.get("id_roblox") is None:
                    raise ValueError("Linha incompatível no CSV existente; arquivo preservado")
                if key not in prepared:
                    raise ValueError("Chave desconhecida no CSV existente: " + key)
                if key in ids:
                    raise ValueError("Chave duplicada no CSV existente: " + key)
                if key:
                    ids[key] = row.get("id_roblox", "")
    (out / "arquivos").mkdir(parents=True, exist_ok=True)
    for _, (pcm, item) in prepared.items():
        destination = out / item["arquivo"]
        with wave.open(str(destination), "wb") as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE); wav.writeframes(pcm)
        item["sha256_wav"] = hashlib.sha256(destination.read_bytes()).hexdigest()
    manifest = {"versao": 1, "status": "preparado_localmente_sem_ids_roblox",
        "politica": {"originais": "preservados", "bordas": "RMS -50dBFS com margem150ms; revisar de ouvido",
                     "ganho_db": 0, "reuso_urso_lobo": "autorizado por Pedro; sem pitch ou áudio duplicado"},
        "gravacoes": {k: item for k, (_, item) in prepared.items()},
        "entradas": entries, "faltantes": missing, "revisar_duracao": warnings}
    (out / "manifesto.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (out / "importacao.csv").open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.writer(file)
        writer.writerow(["chave", "arquivo_wav", "segundos", "original", "id_roblox"])
        for key, (_, item) in prepared.items():
            writer.writerow([key, item["arquivo"], item["segundos"], item["original"], ids.get(key, "")])
    print(f"{len(prepared)} WAV; {len(entries)} entradas; {sum(v['reutilizado'] for v in entries.values())} reusos; {len(warnings)} duracoes para revisar")
    for warning in warnings:
        print(f"DURACAO {warning['chave']}: {warning['segundos']}s > {warning['maximo']}s sugeridos")


if __name__ == "__main__":
    main()

"""Regressões estáticas complementares; runtime Roblox fica no spec Studio."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
def read(name):
    return (root / name).read_text(encoding="utf-8")
for name in ("Npcs", "Treinadores"):
    text = read(f"src/server/Mundo/{name}.luau")
    assert text.count('Instance.new("ProximityPrompt")') == 1, name
    assert '"Falar", "Falar"' in text, name
visual = read("src/server/Mundo/NpcVisual.luau")
assert "gui.AutomaticSize" not in visual
assert "GetTextSize" in visual
assert 'Enum.Font.Bodoni' in visual
assert 'som.SoundId ~= ""' in visual
view = read("src/client/DialogoNpcView.luau")
for intent in ('"lojaListar"', 'ReplicatedStorage.Dojo:FireServer', 'ReplicatedStorage.TreinadorJogo:FireServer', 'Estado.escolher()'):
    assert intent in view, intent
assert 'Dialogo.fechar()' in read("src/client/MissaoView.luau")
print("P1 NPCs: um prompt, Billboard explícito e intenções existentes ok")

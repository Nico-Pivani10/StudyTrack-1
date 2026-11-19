"""Gere novamente após editar os documentos públicos: python scripts/gerar_documentos_legais.py."""
import hashlib
from pathlib import Path
import pprint
import re

root = Path(__file__).resolve().parents[1]
documents = {}
for key, filename in (("termos", "TERMOS_DE_USO.md"), ("privacidade", "AVISO_DE_PRIVACIDADE.md")):
    text = (root / filename).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    version = re.search(r"^Versão ([^ ·]+)", text, re.MULTILINE)
    if not version:
        raise ValueError(f"Informe a versão em {filename}")
    documents[key] = {"titulo": text.splitlines()[0].lstrip("# "), "versao": version[1],
                      "sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(), "texto": text}
output = '# Gerado por scripts/gerar_documentos_legais.py. Edite os arquivos Markdown de origem.\nDOCUMENTOS = '
(root / "api/documentos_legais.py").write_text(output + pprint.pformat(documents, sort_dicts=False, width=100) + "\n", encoding="utf-8")
print("Documentos de uso e privacidade preparados para publicação na API.")

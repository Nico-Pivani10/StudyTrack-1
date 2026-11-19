"""Documentos apresentados no app e validação do aceite explícito das duas versões."""
from api.documentos_legais import DOCUMENTOS


def validar_aceite(aceite):
    if aceite is None:
        return False, None
    if not isinstance(aceite, dict):
        return False, ({"erro": "envie o aceite dos dois documentos", "codigo": "aceite_necessario"}, 428)
    for tipo, documento in DOCUMENTOS.items():
        recebido = aceite.get(tipo)
        if not isinstance(recebido, dict) or recebido.get("aceito") is not True:
            return False, ({"erro": "aceite os Termos de Uso e confirme a leitura do Aviso de Privacidade",
                            "codigo": "aceite_necessario"}, 428)
        if recebido.get("versao") != documento["versao"] or recebido.get("sha256") != documento["sha256"]:
            return False, ({"erro": "os documentos foram atualizados; leia e confirme as versões atuais",
                            "codigo": "documentos_atualizados"}, 409)
    return True, None


def registrar_documentos(app):
    from flask import jsonify

    @app.route("/api/legal/documentos", methods=["GET"])
    def documentos_legais():
        response = jsonify(documentos=DOCUMENTOS)
        response.headers["Cache-Control"] = "no-store"
        return response

"""Validação da identidade Firebase utilizada pelo aplicativo Flutter."""

import json
import os
from threading import Lock


_app_lock = Lock()


def firebase_app():
    import firebase_admin
    from firebase_admin import credentials

    project_id = os.environ.get("FIREBASE_PROJECT_ID", "").strip()
    raw = os.environ.get("FIREBASE_CREDENTIALS", "").strip()
    if not project_id or not raw:
        raise RuntimeError("configure FIREBASE_PROJECT_ID e FIREBASE_CREDENTIALS")
    info = json.loads(raw)
    if info.get("project_id") != project_id:
        raise RuntimeError("as credenciais Firebase devem pertencer ao projeto configurado")
    with _app_lock:
        try:
            return firebase_admin.get_app("studytrack-mobile")
        except ValueError:
            return firebase_admin.initialize_app(
                credentials.Certificate(info), {"projectId": project_id}, name="studytrack-mobile",
            )


def verificar_identidade(id_token):
    from firebase_admin import auth

    return auth.verify_id_token(id_token, app=firebase_app(), check_revoked=True)


def verificar_sessao_firebase(uid, autenticado_em):
    from firebase_admin import auth

    try:
        usuario = auth.get_user(uid, app=firebase_app())
    except (auth.UserNotFoundError, ValueError):
        return False
    return not usuario.disabled and int(autenticado_em) * 1000 >= usuario.tokens_valid_after_timestamp

"""Aceite explícito, documentos apresentados e emissão de sessão."""
import copy
import hashlib
from pathlib import Path
import sys
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from flask import Flask, g
from api.legal import DOCUMENTOS, registrar_documentos
from api.mobile import registrar_mobile


class DocumentosTestes(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.db = Mock()
        self.token = Mock(return_value="token-confirmado")
        registrar_documentos(self.app)
        registrar_mobile(self.app, self.db, self.token)
        self.client = self.app.test_client()
        firebase = ModuleType("firebase_admin")
        firebase.auth = SimpleNamespace(**{name: type(name, (Exception,), {}) for name in (
            "InvalidIdTokenError", "RevokedIdTokenError", "UserDisabledError", "UserNotFoundError")})
        self.firebase_patch = patch.dict(sys.modules, {"firebase_admin": firebase})
        self.firebase_patch.start()
        self.addCleanup(self.firebase_patch.stop)
        self.identity_patch = patch("api.mobile.verificar_identidade", return_value={
            "uid": "novo", "email": "novo@example.com", "name": "Novo", "auth_time": 123})
        self.identity_patch.start()
        self.addCleanup(self.identity_patch.stop)
        self.acceptance = {key: {"aceito": True, "versao": doc["versao"], "sha256": doc["sha256"]}
                           for key, doc in DOCUMENTOS.items()}

    def test_documentos_publicos_correspondem_ao_texto_versionado(self):
        response = self.client.get("/api/legal/documentos")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["Cache-Control"], "no-store")
        for key, filename in (("termos", "TERMOS_DE_USO.md"), ("privacidade", "AVISO_DE_PRIVACIDADE.md")):
            text = (Path(__file__).resolve().parents[1] / filename).read_text(encoding="utf-8-sig")
            doc = response.json["documentos"][key]
            self.assertEqual(doc["texto"], text)
            self.assertEqual(doc["sha256"], hashlib.sha256(text.encode()).hexdigest())

    def test_conta_sem_aceite_nao_recebe_sessao(self):
        self.db.rpc.return_value.execute.return_value.data = {
            "status": 428, "codigo": "aceite_necessario", "erro": "confirme os documentos"}
        response = self.client.post("/api/auth/firebase", json={"id_token": "f" * 30})
        self.assertEqual(response.status_code, 428)
        self.assertFalse(self.db.rpc.call_args.args[1]["p_aceitou"])
        self.token.assert_not_called()

    def test_aceite_envia_ao_banco_as_versoes_e_textos_do_servidor(self):
        self.db.rpc.return_value.execute.return_value.data = {
            "status": 200, "usuario": {"id": 3, "firebase_uid": "novo"}}
        response = self.client.post("/api/auth/firebase", json={"id_token": "f" * 30, "aceite": self.acceptance})
        self.assertEqual(response.status_code, 200)
        self.db.rpc.assert_called_once_with("autenticar_firebase_com_aceite", {
            "p_uid": "novo", "p_email": "novo@example.com", "p_nome": "Novo",
            "p_documentos": DOCUMENTOS, "p_aceitou": True})
        self.token.assert_called_once()

    def test_recusar_um_documento_bloqueia_mesmo_com_o_outro_aceito(self):
        for key in self.acceptance:
            with self.subTest(documento=key):
                acceptance = copy.deepcopy(self.acceptance)
                acceptance[key]["aceito"] = False
                response = self.client.post("/api/auth/firebase", json={"id_token": "f" * 30, "aceite": acceptance})
                self.assertEqual(response.status_code, 428)
        self.db.rpc.assert_not_called()
        self.token.assert_not_called()

    def test_aceite_exige_booleano_explicito(self):
        self.acceptance["termos"]["aceito"] = "true"
        self.assertEqual(self.client.post("/api/auth/firebase", json={
            "id_token": "f" * 30, "aceite": self.acceptance}).status_code, 428)
        self.db.rpc.assert_not_called()

    def test_versao_ou_texto_desatualizado_exige_nova_leitura(self):
        for field in ("versao", "sha256"):
            with self.subTest(campo=field):
                acceptance = copy.deepcopy(self.acceptance)
                acceptance["termos"][field] = "antigo"
                response = self.client.post("/api/auth/firebase", json={"id_token": "f" * 30, "aceite": acceptance})
                self.assertEqual(response.status_code, 409)
                self.assertEqual(response.json["codigo"], "documentos_atualizados")
        self.db.rpc.assert_not_called()
        self.token.assert_not_called()

    def test_aceite_ja_registrado_permite_login_sem_nova_confirmacao(self):
        self.db.rpc.return_value.execute.return_value.data = {
            "status": 200, "usuario": {"id": 3, "firebase_uid": "novo"}}
        self.assertEqual(self.client.post("/api/auth/firebase", json={"id_token": "f" * 30}).status_code, 200)
        self.assertFalse(self.db.rpc.call_args.args[1]["p_aceitou"])


if __name__ == "__main__":
    unittest.main()

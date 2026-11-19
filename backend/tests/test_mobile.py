"""Contrato HTTP mobile com Flask real e serviços externos simulados."""

import base64
from datetime import datetime, timezone
import sys
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from flask import Flask, g

from api.mobile import converter_firestore, registrar_mobile, validar_dados
from api.legal import DOCUMENTOS


class IntegracaoMobileTestes(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.db = Mock()
        self.criar_token = Mock(return_value="jwt-ficticio")
        self.usuario = {"id": 12, "firebase_uid": "uid-a", "senha_hash": None}
        self.claims = {"iat": int(datetime.now(timezone.utc).timestamp())}

        @self.app.before_request
        def identidade_teste():
            g.usuario_id = 12
            g.usuario = self.usuario
            g.jwt_claims = self.claims

        registrar_mobile(self.app, self.db, self.criar_token)
        self.client = self.app.test_client()

    def test_estado_preserva_id_documento_e_id_android(self):
        estado = {
            "perfil": {"nombre": "Teste"}, "materias": [], "tareas": [], "examenes": [],
            "sesionesEstudio": [], "notificaciones": [{"id": "doc-a", "dados": {"id": 51, "leida": False}}],
        }
        self.db.rpc.return_value.execute.return_value.data = estado
        resposta = self.client.get("/api/mobile/estado")
        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(resposta.json, estado)
        self.db.rpc.assert_called_once_with("mobile_estado", {"p_usuario_id": 12})

    def test_update_parcial_tarefa_chega_a_transacao(self):
        self.db.rpc.return_value.execute.return_value.data = {
            "status": 200, "registro": {"id": "tarefa-a", "dados": {"titulo": "Lista", "completada": True}},
        }
        resposta = self.client.put("/api/mobile/tareas/tarefa-a", json={"completada": True})
        self.assertEqual(resposta.status_code, 200)
        self.db.rpc.assert_called_once_with("mobile_gravar", {
            "p_usuario_id": 12, "p_tipo": "tareas", "p_id": "tarefa-a",
            "p_dados": {"completada": True}, "p_importar": False, "p_atualizar": False,
        })

    def test_patch_exige_registro_existente(self):
        self.db.rpc.return_value.execute.return_value.data = {"status": 404, "erro": "registro não encontrado"}
        resposta = self.client.patch("/api/mobile/tareas/removida", json={"completada": True})
        self.assertEqual(resposta.status_code, 404)
        self.db.rpc.assert_called_once_with("mobile_gravar", {
            "p_usuario_id": 12, "p_tipo": "tareas", "p_id": "removida",
            "p_dados": {"completada": True}, "p_importar": False, "p_atualizar": True,
        })

    def test_vinculo_exige_duas_autenticacoes_recentes(self):
        firebase = ModuleType("firebase_admin")
        firebase.auth = SimpleNamespace(**{name: type(name, (Exception,), {}) for name in (
            "InvalidIdTokenError", "RevokedIdTokenError", "UserDisabledError", "UserNotFoundError",
        )})
        self.usuario.update(email="a@example.com", senha_hash="hash-legado", firebase_uid=None)
        identidade = {"uid": "uid-a", "email": "a@example.com", "auth_time": self.claims["iat"]}
        self.db.rpc.return_value.execute.return_value.data = {"status": 200, "usuario": self.usuario}
        with patch.dict(sys.modules, {"firebase_admin": firebase}), patch("api.mobile.verificar_identidade", return_value=identidade):
            resposta = self.client.post("/api/auth/firebase/vincular", json={"id_token": "f" * 30})
            self.assertEqual(resposta.status_code, 200)
            self.db.rpc.assert_called_with("vincular_firebase_com_aceite", {
                "p_usuario_id": 12, "p_uid": "uid-a", "p_senha_hash": "hash-legado",
                "p_documentos": DOCUMENTOS, "p_aceitou": False,
            })
            self.claims["iat"] -= 600
            self.assertEqual(self.client.post("/api/auth/firebase/vincular", json={"id_token": "f" * 30}).status_code, 401)
            self.claims["iat"] += 600
            identidade["auth_time"] -= 600
            self.assertEqual(self.client.post("/api/auth/firebase/vincular", json={"id_token": "f" * 30}).status_code, 401)
            self.claims["origem"] = "firebase"
            self.assertEqual(self.client.post("/api/auth/firebase/vincular", json={"id_token": "f" * 30}).status_code, 403)

    def test_foto_e_datas_sao_validadas(self):
        dados = converter_firestore({"fotoPerfilBytes": b"foto", "fecha": datetime(2026, 11, 18, tzinfo=timezone.utc)})
        self.assertEqual(dados["fotoPerfilBytes"], base64.b64encode(b"foto").decode())
        validar_dados("perfil", dados)
        self.assertEqual(self.client.patch("/api/mobile/perfil", json={"fotoPerfilBytes": "%%%invalida"}).status_code, 400)
        self.assertEqual(self.client.put("/api/mobile/tareas/a", json={"fechaEntrega": "ontem"}).status_code, 400)
        self.db.rpc.assert_not_called()

    def test_perfil_nulo_chega_ao_merge(self):
        self.db.rpc.return_value.execute.return_value.data = {"status": 200, "perfil": {"nombre": "Teste"}}
        resposta = self.client.patch("/api/mobile/perfil", json={"nombre": "Teste", "fotoPerfilBytes": None})
        self.assertEqual(resposta.status_code, 200)
        self.db.rpc.assert_called_once_with("mobile_perfil", {
            "p_usuario_id": 12, "p_dados": {"nombre": "Teste", "fotoPerfilBytes": None}, "p_importar": False,
        })

    def test_importacao_concluida_dispensa_firestore(self):
        self.usuario["mobile_importado_em"] = "2026-11-18T12:00:00Z"
        with patch("api.mobile.firebase_app", side_effect=AssertionError("não deve inicializar Firestore")):
            resposta = self.client.post("/api/mobile/importar")
        self.assertEqual(resposta.status_code, 200)
        self.assertTrue(resposta.json["ja_importado"])
        self.db.rpc.assert_not_called()

    def test_troca_token_valida_identidade_e_recusa_merge_por_email(self):
        firebase = ModuleType("firebase_admin")
        firebase.auth = SimpleNamespace(
            InvalidIdTokenError=type("InvalidIdTokenError", (Exception,), {}),
            RevokedIdTokenError=type("RevokedIdTokenError", (Exception,), {}),
            UserDisabledError=type("UserDisabledError", (Exception,), {}),
            UserNotFoundError=type("UserNotFoundError", (Exception,), {}),
        )
        claims = {"uid": "uid-a", "email": "a@example.com", "name": "Teste", "auth_time": 123}
        with patch.dict(sys.modules, {"firebase_admin": firebase}), \
             patch("api.mobile.verificar_identidade", return_value=claims):
            self.db.rpc.return_value.execute.return_value.data = {
                "status": 409, "codigo": "conta_nao_vinculada", "erro": "confirme as duas contas",
            }
            bloqueada = self.client.post("/api/auth/firebase", json={"id_token": "f" * 30})
            self.assertEqual(bloqueada.status_code, 409)
            self.criar_token.assert_not_called()
            self.db.rpc.return_value.execute.return_value.data = {"status": 200, "usuario": self.usuario}
            resposta = self.client.post("/api/auth/firebase", json={"id_token": "f" * 30})
            self.assertEqual(resposta.status_code, 200)
            self.assertNotIn("senha_hash", resposta.json["usuario"])
            self.criar_token.assert_called_once_with(self.usuario, claims)


if __name__ == "__main__":
    unittest.main()

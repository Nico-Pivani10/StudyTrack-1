"""Testes dos módulos novos com o banco e o push simulados."""
import os
import hashlib
import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import Mock, patch
from zoneinfo import ZoneInfo

from test_api import Banco, carregar_api, Args


class TestesNovosRecursos(unittest.TestCase):
    def setUp(self):
        self.api, self.req = carregar_api()
        self.api.supabase = Banco()
        # As rotas complementares recebem supabase por injeção quando o módulo é carregado.
        # Portanto, apontamos também os handlers para o mesmo banco criado no import.
        self.db = self.api.g and self._db_closures()
        self.api.g.usuario_id = 1
        self.api.g.usuario = {"id": 1, "senha_hash": self.api.hash_senha("senha12345"), "plano": "premium"}
        self.db.table("usuarios").insert({"id": 1, "nome": "Estudante", "email": "e@teste.com",
            "senha_hash": self.api.g.usuario["senha_hash"], "plano": "premium"}).execute()

    def _db_closures(self):
        # O cliente original do import é utilizado nas novas rotas por closures.
        db = self.api.supabase
        from api.recursos import registrar_rotas_complementares
        registrar_rotas_complementares(self.api.app, db, self.api.g, self.req,
            self.api.jsonify, self.api._exigir_propriedade, self.api.hash_senha,
            self.api.enviar_push, self.api.exigir_premium)
        return db

    def executar(self, rota, dados=None, args=None, headers=None, **path_params):
        self.req.dados = dados or {}
        self.req.args = Args(args or {})
        self.req.headers = headers or {}
        func = self.api.app.rotas[rota]
        return func(**path_params)

    def _materia(self, usuario=1):
        return self.db.table("materias").insert({"usuario_id": usuario, "nome": "Matemática", "cor": "#ABCDEF"}).execute().data[0]["id"]

    def test_preferencias_consulta_atualiza_e_recusa_invalido(self):
        dados, codigo = self.executar(("GET", "/api/preferencias"))
        self.assertEqual(codigo, 200)
        self.assertTrue(dados["preferencias"]["notif_tarefas"])
        dados, codigo = self.executar(("PUT", "/api/preferencias"), {"fuso_horario": "America/Sao_Paulo", "hora_lembrete_estudo": "19:30", "gps_ativo": False})
        self.assertEqual(codigo, 200)
        self.assertFalse(dados["preferencias"]["gps_ativo"])
        dados, codigo = self.executar(("PUT", "/api/preferencias"), {"notif_tarefas": "false"})
        self.assertEqual(codigo, 400)
        dados, codigo = self.executar(("PUT", "/api/preferencias"), {"antecedencia_exames_minutos": 50000})
        self.assertEqual(codigo, 400)
        dados, codigo = self.executar(("PUT", "/api/preferencias"), {"usuario_id": 9})
        self.assertEqual(codigo, 400)

    def test_free_recusa_locais_qr_e_preferencias_premium(self):
        self.api.g.usuario["plano"] = "free"
        for rota in (("GET", "/api/locais"), ("GET", "/api/qrcodes")):
            with self.subTest(rota=rota):
                resposta, status = self.executar(rota)
                self.assertEqual((status, resposta["plano_necessario"]), (402, "premium"))
        resposta, status = self.executar(("PUT", "/api/preferencias"), {
            "antecedencia_tarefas_minutos": 30,
        })
        self.assertEqual((status, resposta["plano_necessario"]), (402, "premium"))
        resposta, status = self.executar(("PUT", "/api/preferencias"), {"notif_tarefas": False})
        self.assertEqual(status, 200)
        self.assertFalse(resposta["preferencias"]["notif_tarefas"])

    def test_crud_locais_e_bloqueio_entre_alunos(self):
        corpo = {"tipo": "instituicao", "latitude": -23.55, "longitude": -46.63, "raio_metros": 200}
        dado, status = self.executar(("POST", "/api/locais"), corpo)
        self.assertEqual(status, 201)
        local_id = dado["local"]["id"]
        dado, status = self.executar(("GET", "/api/locais"))
        self.assertEqual(len(dado["locais"]), 1)
        dado, status = self.executar(("PUT", "/api/locais/<int:local_id>"), {"raio_metros": 300}, local_id=local_id)
        # A rota usa o argumento da função, como faria o Flask.
        self.assertEqual(status, 200)
        self.assertEqual(dado["local"]["raio_metros"], 300)
        self.api.g.usuario_id = 2
        dado, status = self.executar(("DELETE", "/api/locais/<int:local_id>"), local_id=local_id)
        self.assertEqual(status, 404)
        self.api.g.usuario_id = 1
        dado, status = self.executar(("DELETE", "/api/locais/<int:local_id>"), local_id=local_id)
        self.assertEqual(status, 200)

    def test_tipo_local_usa_enum_confirmado(self):
        base = {"latitude": -23.55, "longitude": -46.63}
        for tipo in ("casa", "instituicao"):
            with self.subTest(tipo=tipo):
                ret, status = self.executar(("POST", "/api/locais"), {**base, "tipo": tipo})
                self.assertEqual(status, 201)
                self.assertEqual(ret["local"]["tipo"], tipo)
        for tipo in ("escola", "Casa", "instituição", "", None):
            with self.subTest(tipo=tipo):
                ret, status = self.executar(("POST", "/api/locais"), {**base, "tipo": tipo})
                self.assertEqual(status, 400)
                self.assertIn("tipo", ret["erro"])
        local_id = self.db.dados["locais"][0]["id"]
        ret, status = self.executar(("PUT", "/api/locais/<int:local_id>"), {"tipo": "faculdade"}, local_id=local_id)
        self.assertEqual(status, 400)
        self.assertEqual(len(self.db.dados["locais"]), 2)

    def test_compromissos_hoje_usam_iso_domingo_7(self):
        materia = self._materia()
        for dia in (1, 7):
            self.db.table("horarios_aula").insert({
                "materia_id": materia, "dia_semana": dia,
                "hora_inicio": "08:00", "hora_fim": "09:00",
            }).execute()
        with patch("api.recursos.datetime") as dt:
            dt.now.return_value.date.return_value.isoformat.return_value = "2026-10-25"
            resultado, status = self.executar(("GET", "/api/compromissos-hoje"))
        self.assertEqual(status, 200)
        self.assertEqual(len(resultado["compromissos"]["aulas"]), 1)
        self.assertEqual(resultado["compromissos"]["aulas"][0]["dia_semana"], 7)
        with patch("api.recursos.datetime") as dt:
            dt.now.return_value.date.return_value.isoformat.return_value = "2026-10-26"
            resultado, status = self.executar(("GET", "/api/compromissos-hoje"))
        self.assertEqual(status, 200)
        self.assertEqual(len(resultado["compromissos"]["aulas"]), 1)
        self.assertEqual(resultado["compromissos"]["aulas"][0]["dia_semana"], 1)

    def test_gps_respeita_preferencia_e_nao_armazena_posicao(self):
        local = self.db.table("locais").insert({"usuario_id": 1, "tipo": "instituicao", "latitude": -23.55, "longitude": -46.63, "raio_metros": 200}).execute().data[0]
        corpo = {"local_id": local["id"], "latitude": -23.55, "longitude": -46.63}
        self.db.table("preferencias_notificacao").insert({"usuario_id": 1, "gps_ativo": False}).execute()
        dado, codigo = self.executar(("POST", "/api/gps/chegada"), corpo)
        self.assertEqual(codigo, 403)
        self.db.dados["preferencias_notificacao"][0]["gps_ativo"] = True
        dado, codigo = self.executar(("POST", "/api/gps/chegada"), corpo)
        self.assertEqual(codigo, 200)
        self.assertTrue(dado["proximo"])
        self.assertEqual(dado["distancia_metros"], 0)
        self.assertNotIn("latitude_atual", str(self.db.dados))

    def test_qr_material_e_isolamento(self):
        materia = self._materia()
        corpo = {"materia_id": materia, "tipo": "material", "titulo": "Apostila", "url": "https://exemplo.org/material.pdf"}
        dado, status = self.executar(("POST", "/api/qrcodes"), corpo)
        self.assertEqual(status, 201)
        codigo = dado["codigo"]["codigo"]
        dado, status = self.executar(("GET", "/api/qrcodes/<string:codigo>"), codigo=codigo)
        self.assertEqual(status, 200)
        self.api.g.usuario_id = 2
        dado, status = self.executar(("GET", "/api/qrcodes/<string:codigo>"), codigo=codigo)
        self.assertEqual(status, 404)
        self.api.g.usuario_id = 1
        dado, status = self.executar(("POST", "/api/qrcodes"), {**corpo, "url": "http://inseguro.test"})
        self.assertEqual(status, 400)

    def test_recuperacao_senha_token_uso_unico(self):
        ambiente = {"SMTP_HOST": "smtp.exemplo.test", "SMTP_FROM": "naoresponder@exemplo.test", "PASSWORD_RESET_URL": "https://exemplo.org/reset"}
        tokens = []
        def capturar(email, nome, token):
            tokens.append(token)
        with patch.dict(os.environ, ambiente), patch("api.recursos._enviar_email_redefinicao", side_effect=capturar):
            dado, status = self.executar(("POST", "/api/auth/recuperar-senha"), {"email": "e@teste.com"})
            self.assertEqual(status, 200)
            self.assertEqual(len(tokens), 1)
            antigo = self.db.dados["usuarios"][0]["senha_hash"]
            dado, status = self.executar(("POST", "/api/auth/redefinir-senha"), {"token": tokens[0], "nova_senha": "novasenha123"})
            self.assertEqual(status, 200)
            self.assertNotEqual(self.db.dados["usuarios"][0]["senha_hash"], antigo)
            dado, status = self.executar(("POST", "/api/auth/redefinir-senha"), {"token": tokens[0], "nova_senha": "novasenha456"})
            self.assertEqual(status, 400)

    def test_cron_autenticacao_e_envio_uma_vez(self):
        materia = self._materia()
        # Uma tarefa 24h e 7min no futuro deve cair na janela de 15min.
        prazo = (datetime.now(ZoneInfo("America/Sao_Paulo")) + timedelta(hours=24, minutes=7)).replace(tzinfo=None)
        self.db.table("tarefas").insert({"materia_id": materia, "titulo": "Estudar", "data_entrega": prazo.isoformat(), "status": "pendente"}).execute()
        self.db.table("dispositivos").insert({"usuario_id": 1, "fcm_token": "token123"}).execute()
        chamadas = []
        def push_mock(token, titulo, corpo, dados, *, usuario_id):
            chamadas.append((token, titulo, usuario_id))
            return (True, "enviado")
        from api.recursos import registrar_rotas_complementares
        registrar_rotas_complementares(self.api.app, self.db, self.api.g, self.req,
            self.api.jsonify, self.api._exigir_propriedade, self.api.hash_senha,
            push_mock, self.api.exigir_premium)
        with patch.dict(os.environ, {"CRON_SECRET": "segredo" * 8}):
            dado, codigo = self.executar(("POST", "/api/interno/processar-lembretes"), headers={"X-Cron-Secret": "invalido"})
            self.assertEqual(codigo, 401)
            dado, codigo = self.executar(("POST", "/api/interno/processar-lembretes"), headers={"X-Cron-Secret": "segredo" * 8})
            self.assertEqual(codigo, 200)
            self.assertEqual(dado["enviados"], 1)
            dado, codigo = self.executar(("POST", "/api/interno/processar-lembretes"), headers={"X-Cron-Secret": "segredo" * 8})
            self.assertEqual(dado["ignorados"], 1)
            self.assertEqual(len(chamadas), 1)

    def test_cron_remove_token_invalido_sem_usuario_logado(self):
        materia = self._materia()
        prazo = datetime.now(ZoneInfo("America/Sao_Paulo")).replace(tzinfo=None) + timedelta(days=1)
        self.db.table("tarefas").insert({
            "materia_id": materia, "data_entrega": prazo.isoformat(), "status": "pendente",
        }).execute()
        self.db.table("dispositivos").insert([
            {"usuario_id": 1, "fcm_token": "expirado"}, {"usuario_id": 2, "fcm_token": "outro"},
        ]).execute()
        del self.api.g.usuario_id
        segredo = "t" * 40
        credenciais = SimpleNamespace(project_id="teste", token="ficticio")
        fcm = SimpleNamespace(status_code=404, text="UNREGISTERED")
        with patch.dict(os.environ, {"CRON_SECRET": segredo}), \
             patch.object(self.api, "_credenciais_fcm", return_value=credenciais), \
             patch("requests.post", return_value=fcm):
            dados, status = self.executar(("POST", "/api/interno/processar-lembretes"),
                                          headers={"X-Cron-Secret": segredo})
        self.assertEqual((status, dados["falhas"]), (200, 1))
        self.assertEqual([d["fcm_token"] for d in self.db.dados["dispositivos"]], ["outro"])

    def test_cron_reconsidera_lembretes_atrasados_e_reservas_vencidas(self):
        from api.recursos import registrar_rotas_complementares

        materia = self._materia()
        instante = datetime(2026, 11, 5, 15, tzinfo=timezone.utc)
        agora_local = instante.astimezone(ZoneInfo("America/Sao_Paulo")).replace(tzinfo=None)
        prazo = (agora_local + timedelta(hours=23, minutes=35)).isoformat()
        self.db.table("dispositivos").insert({"usuario_id": 1, "fcm_token": "teste"}).execute()
        for estado in ("falha", "processando", "enviado"):
            tarefa = self.db.table("tarefas").insert({
                "materia_id": materia, "data_entrega": prazo, "status": "pendente",
            }).execute().data[0]
            self.db.table("notificacoes_processadas").insert({
                "usuario_id": 1, "tipo": "tarefa", "referencia_id": tarefa["id"],
                "janela": f"{prazo}:1440", "status": estado,
                "atualizado_em": (instante - timedelta(minutes=20)).isoformat(),
            }).execute()
        enviar = Mock(return_value=(True, "ok"))
        registrar_rotas_complementares(self.api.app, self.db, self.api.g, self.req,
            self.api.jsonify, self.api._exigir_propriedade, self.api.hash_senha,
            enviar, self.api.exigir_premium)
        segredo = "t" * 40
        with patch.dict(os.environ, {"CRON_SECRET": segredo}), patch("api.recursos.datetime", wraps=datetime) as relogio:
            relogio.now.return_value = instante
            dados, status = self.executar(("POST", "/api/interno/processar-lembretes"),
                                          headers={"X-Cron-Secret": segredo})
        self.assertEqual((status, dados["enviados"], dados["ignorados"]), (200, 2, 1))
        self.assertEqual(enviar.call_count, 2)
        self.assertTrue(all(n["status"] == "enviado" for n in self.db.dados["notificacoes_processadas"]))

    def test_qr_registra_leitura_e_rejeita_atividade_excluida(self):
        materia = self._materia()
        tarefa = self.db.table("tarefas").insert({"materia_id": materia, "titulo": "Lista", "data_entrega": "2026-10-31T10:00:00", "status": "pendente"}).execute().data[0]
        codigo, status = self.executar(("POST", "/api/qrcodes"), {
            "materia_id": materia, "tipo": "tarefa", "titulo": "Atividade 1", "referencia_id": tarefa["id"]})
        self.assertEqual(status, 201)
        codigo = codigo["codigo"]["codigo"]
        dado, status = self.executar(("POST", "/api/qrcodes/<string:codigo>/registrar"), codigo=codigo)
        self.assertEqual(status, 201)
        self.assertEqual(len(self.db.dados["leituras_qr"]), 1)
        self.db.table("tarefas").delete().eq("id", tarefa["id"]).execute()
        dado, status = self.executar(("GET", "/api/qrcodes/<string:codigo>"), codigo=codigo)
        self.assertEqual(status, 404)

    def test_notificacao_estudo_respeita_preferencias(self):
        horario = datetime.now(ZoneInfo("America/Sao_Paulo"))
        # Envio 5 minutos atrás está dentro do intervalo de execução do cron.
        hora = (horario - timedelta(minutes=5)).strftime("%H:%M")
        self.db.table("preferencias_notificacao").insert({"usuario_id": 1,
            "hora_lembrete_estudo": hora, "notif_lembrete_estudo": False}).execute()
        self.db.table("dispositivos").insert({"usuario_id": 1, "fcm_token": "teste"}).execute()
        from api.recursos import registrar_rotas_complementares
        env = {"CRON_SECRET": "t" * 48}
        enviados = []
        registrar_rotas_complementares(self.api.app, self.db, self.api.g, self.req,
            self.api.jsonify, self.api._exigir_propriedade, self.api.hash_senha,
             lambda *args, **kwargs: (enviados.append(args) or True, "ok"), self.api.exigir_premium)
        with patch.dict(os.environ, env):
            dado, status = self.executar(("POST", "/api/interno/processar-lembretes"), headers={"X-Cron-Secret": "t" * 48})
            self.assertEqual(status, 200)
            self.assertEqual(dado["enviados"], 0)
            self.db.dados["preferencias_notificacao"][0]["notif_lembrete_estudo"] = True
            dado, status = self.executar(("POST", "/api/interno/processar-lembretes"), headers={"X-Cron-Secret": "t" * 48})
            self.assertEqual(status, 200)
            self.assertEqual(dado["enviados"], 1)
            self.assertEqual(len(enviados), 1)

    def test_recuperacao_nao_revela_email_inexistente(self):
        ambiente = {"SMTP_HOST": "smtp.exemplo.test", "SMTP_FROM": "teste@exemplo.test", "PASSWORD_RESET_URL": "https://exemplo.org/redefinir"}
        with patch.dict(os.environ, ambiente), patch("api.recursos._enviar_email_redefinicao") as simular:
            dado, status = self.executar(("POST", "/api/auth/recuperar-senha"), {"email": "naoexiste@exemplo.test"})
            self.assertEqual(status, 200)
            self.assertNotIn("não encontrado", str(dado))
            simular.assert_not_called()

    def test_recuperacao_legada_nao_cria_senha_paralela_ao_firebase(self):
        self.db.dados["usuarios"][0]["firebase_uid"] = "uid-a"
        ambiente = {"SMTP_HOST": "smtp.exemplo.test", "SMTP_FROM": "teste@exemplo.test", "PASSWORD_RESET_URL": "https://exemplo.org/redefinir"}
        with patch.dict(os.environ, ambiente), patch("api.recursos._enviar_email_redefinicao") as enviar:
            _, status = self.executar(("POST", "/api/auth/recuperar-senha"), {"email": "e@teste.com"})
        self.assertEqual(status, 200)
        enviar.assert_not_called()
        self.assertEqual(self.db.dados["tokens_redefinicao_senha"], [])


if __name__ == "__main__":
    unittest.main()

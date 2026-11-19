"""Testes isolados das rotas: não acessam Supabase nem enviam push reais."""
import importlib.util
import hashlib
from datetime import datetime, timedelta, timezone
import logging
import jwt
import itertools
import pathlib
import sys
import types
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]


class Query:
    def __init__(self, banco, tabela):
        self.banco, self.tabela = banco, tabela
        self.condicoes = []
        self.acao = "select"
        self.payload = None
        self.ordem = None
        self.contagem = None

    def select(self, *args, count=None):
        self.acao = "select"
        self.contagem = count
        return self

    def insert(self, dados):
        self.acao, self.payload = "insert", dados
        return self

    def update(self, dados):
        self.acao, self.payload = "update", dados
        return self

    def delete(self):
        self.acao = "delete"
        return self

    def upsert(self, dados, on_conflict=None):
        self.acao, self.payload = "upsert", dados
        self.conflito = on_conflict
        return self

    def eq(self, campo, valor):
        self.condicoes.append(("eq", campo, valor))
        return self

    def in_(self, campo, valores):
        self.condicoes.append(("in", campo, valores))
        return self

    def lt(self, campo, valor):
        self.condicoes.append(("lt", campo, valor))
        return self

    def lte(self, campo, valor):
        self.condicoes.append(("lte", campo, valor))
        return self

    def gte(self, campo, valor):
        self.condicoes.append(("gte", campo, valor))
        return self

    def order(self, coluna):
        self.ordem = coluna
        return self

    def _enriquecer(self, linha):
        row = dict(linha)
        if self.tabela in ("tarefas", "exames", "horarios_aula", "codigos_qr"):
            materia = next((m for m in self.banco.dados["materias"] if m["id"] == row.get("materia_id")), None)
            row["materias"] = dict(materia) if materia else None
        if self.tabela == "materias":
            row["horarios_aula"] = [dict(h) for h in self.banco.dados["horarios_aula"] if h["materia_id"] == row["id"]]
        return row

    def _filtrar(self, rows):
        encontrados = []
        for row in rows:
            completo = self._enriquecer(row)
            aceito = True
            for operador, campo, esperado in self.condicoes:
                if "." in campo:
                    tabela, campo2 = campo.split(".", 1)
                    valor = (completo.get(tabela) or {}).get(campo2)
                else:
                    valor = completo.get(campo)
                if operador == "eq":
                    valido = valor == esperado
                elif operador == "in":
                    valido = valor in esperado
                elif operador == "gte":
                    valido = valor is not None and valor >= esperado
                elif operador == "lte":
                    valido = valor is not None and valor <= esperado
                else:
                    valido = valor is not None and valor < esperado
                if not valido:
                    aceito = False
                    break
            if aceito:
                encontrados.append(completo)
        if self.ordem:
            encontrados.sort(key=lambda r: str(r.get(self.ordem) or ""))
        return encontrados

    def execute(self):
        rows = self.banco.dados[self.tabela]
        filtrados = self._filtrar(rows)
        if self.acao == "select":
            result = filtrados
        elif self.acao == "insert":
            novas = self.payload if isinstance(self.payload, list) else [self.payload]
            result = []
            for nova in novas:
                copia = dict(nova)
                copia.setdefault("id", next(self.banco.ids))
                if self.tabela == "usuarios":
                    copia.setdefault("plano", "free")
                    copia.setdefault("firebase_uid", None)
                    copia.setdefault("premium_desde", None)
                    copia.setdefault("mobile_importado_em", None)
                if self.tabela in ("tarefas", "exames"):
                    materia = next((m for m in self.banco.dados["materias"]
                                    if m["id"] == copia.get("materia_id")), None)
                    if materia:
                        copia["usuario_id"] = materia["usuario_id"]
                rows.append(copia)
                result.append(dict(copia))
        elif self.acao == "update":
            result = []
            for row in filtrados:
                original = next(r for r in rows if r["id"] == row["id"])
                original.update(self.payload)
                result.append(dict(original))
        elif self.acao == "delete":
            ids = {r.get("id", r.get("token_hash")) for r in filtrados}
            self.banco.dados[self.tabela] = [r for r in rows if r.get("id", r.get("token_hash")) not in ids]
            result = filtrados
        elif self.acao == "upsert":
            antigo = next((r for r in rows if r[self.conflito] == self.payload[self.conflito]), None)
            if antigo:
                antigo.update(self.payload)
                result = [dict(antigo)]
            else:
                novo = dict(self.payload, id=next(self.banco.ids))
                rows.append(novo)
                result = [novo]
        return types.SimpleNamespace(data=result, count=len(filtrados) if self.contagem else None)


class Banco:
    def __init__(self):
        self.ids = itertools.count(1)
        self.dados = {nome: [] for nome in (
            "usuarios", "materias", "horarios_aula", "tarefas", "exames",
            "dispositivos", "locais", "preferencias_notificacao", "tokens_revogados",
            "codigos_qr", "tokens_redefinicao_senha", "notificacoes_processadas", "leituras_qr"
        )}

    def table(self, nome):
        return Query(self, nome)

    def rpc(self, nome, argumentos):
        banco = self
        class ResultadoRpc:
            def execute(self):
                if nome == "consumir_token_redefinicao":
                    reg = next((r for r in banco.dados["tokens_redefinicao_senha"]
                                if r["token_hash"] == argumentos["p_token_hash"]
                                and not r.get("usado_em")
                                and datetime.fromisoformat(r["expira_em"]) > datetime.now(timezone.utc)), None)
                    if reg is None:
                        return types.SimpleNamespace(data=False)
                    reg["usado_em"] = datetime.now(timezone.utc).isoformat()
                    usuario = next(u for u in banco.dados["usuarios"] if u["id"] == reg["usuario_id"])
                    usuario["senha_hash"] = argumentos["p_novo_hash"]
                    return types.SimpleNamespace(data=True)
                if nome == "reservar_notificacao":
                    row = next((r for r in banco.dados["notificacoes_processadas"]
                                if (r["usuario_id"], r["tipo"], r["referencia_id"], r["janela"]) ==
                                (argumentos["p_usuario_id"], argumentos["p_tipo"],
                                 argumentos["p_referencia_id"], argumentos["p_janela"])), None)
                    reservado_em = argumentos["p_reservado_em"]
                    if row:
                        idade = datetime.fromisoformat(reservado_em) - datetime.fromisoformat(row["atualizado_em"])
                        if row["status"] == "enviado" or idade < timedelta(minutes=10):
                            return types.SimpleNamespace(data=None)
                        row.update(status="processando", atualizado_em=reservado_em)
                        return types.SimpleNamespace(data=row["id"])
                    novo = {"id": next(banco.ids), "usuario_id": argumentos["p_usuario_id"],
                            "tipo": argumentos["p_tipo"], "referencia_id": argumentos["p_referencia_id"],
                            "janela": argumentos["p_janela"], "status": "processando",
                            "atualizado_em": reservado_em}
                    banco.dados["notificacoes_processadas"].append(novo)
                    return types.SimpleNamespace(data=novo["id"])
                if nome == "excluir_conta_studytrack":
                    uid = argumentos["p_usuario_id"]
                    if not any(u["id"] == uid for u in banco.dados["usuarios"]):
                        return types.SimpleNamespace(data=False)
                    materia_ids = {m["id"] for m in banco.dados["materias"] if m["usuario_id"] == uid}
                    for tabela in ("tarefas", "exames", "horarios_aula"):
                        banco.dados[tabela] = [r for r in banco.dados[tabela] if r["materia_id"] not in materia_ids]
                    for tabela in ("materias", "dispositivos", "locais", "preferencias_notificacao",
                                   "tokens_revogados", "tokens_redefinicao_senha", "notificacoes_processadas", "leituras_qr"):
                        banco.dados[tabela] = [r for r in banco.dados[tabela] if r.get("usuario_id") != uid]
                    banco.dados["codigos_qr"] = [r for r in banco.dados["codigos_qr"] if r["materia_id"] not in materia_ids]
                    banco.dados["usuarios"] = [u for u in banco.dados["usuarios"] if u["id"] != uid]
                    return types.SimpleNamespace(data=True)
                raise ValueError("RPC não conhecida: " + nome)
        return ResultadoRpc()


class Args(dict):
    def get(self, chave, default=None, type=None):
        valor = super().get(chave, default)
        if type is None or valor is None:
            return valor
        try:
            return type(valor)
        except (TypeError, ValueError):
            return default


class Solicitacao:
    def __init__(self):
        self.dados = {}
        self.args = Args()
        self.path = "/api/auth/me"
        self.method = "GET"
        self.headers = {}

    def get_json(self, silent=False):
        return self.dados


class App:
    def __init__(self, name):
        self.rotas = {}
        self.logger = logging.getLogger("studytrack-test")

    def before_request(self, fn):
        self.before = fn
        return fn

    def route(self, caminho, methods=None):
        def decorar(fn):
            for metodo in methods or ["GET"]:
                self.rotas[metodo, caminho] = fn
            return fn
        return decorar

    def after_request(self, fn):
        return fn


def carregar_api():
    flask = types.ModuleType("flask")
    req = Solicitacao()
    flask.Flask = App
    flask.request = req
    flask.g = types.SimpleNamespace(usuario_id=1, usuario={"id": 1}, jwt_claims={})
    flask.jsonify = lambda *args, **kwargs: args[0] if args else kwargs
    supabase_mod = types.ModuleType("supabase")
    supabase_mod.Client = Banco
    supabase_mod.create_client = lambda *_: Banco()
    bcrypt = types.ModuleType("bcrypt")
    bcrypt.gensalt = lambda: b"salt"
    bcrypt.hashpw = lambda senha, salt: b"teste$" + hashlib.sha256(senha).hexdigest().encode()
    bcrypt.checkpw = lambda senha, hash_valor: bcrypt.hashpw(senha, b"salt") == hash_valor
    caminho = ROOT / "api" / "index.py"
    spec = importlib.util.spec_from_file_location("studytrack_api_sob_teste", caminho)
    modulo = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, {"flask": flask, "supabase": supabase_mod, "bcrypt": bcrypt}), patch.dict("os.environ", {"SUPABASE_URL": "https://exemplo.supabase.co", "SUPABASE_KEY": "teste", "JWT_SECRET": "chave-de-teste-para-jwt-com-mais-de-32-caracteres"}):
        spec.loader.exec_module(modulo)
    return modulo, req


class EstudoTestes(unittest.TestCase):
    def setUp(self):
        self.api, self.req = carregar_api()
        self.api.supabase = Banco()
        self.api.g.usuario_id = 1
        self.api.g.usuario = {"id": 1, "senha_hash": self.api.hash_senha("12345678")}
        self.api.g.jwt_claims = {}

    def executar(self, nome, corpo=None, args=None):
        self.req.dados = corpo or {}
        self.req.args = Args(args or {})
        return getattr(self.api, nome)()

    def criar_materia(self, nome="Matemática"):
        self.api.supabase.table("usuarios").insert({"id": 1, "nome": "Ana", "email": "a@exemplo.com"}).execute()
        resposta, status = self.executar("criar_materia", {"usuario_id": 1, "nome": nome, "cor": "#ABCDEF", "horarios": [{"dia_semana": 1, "hora_inicio": "08:00", "hora_fim": "09:00"}]})
        self.assertEqual(status, 201)
        return resposta["materia"]["id"]

    def test_cadastro_edicao_listagem_exclusao_usuario(self):
        ret, code = self.executar("criar_usuario", {"nome": "Ana", "email": "A@EXEMPLO.COM", "senha": "12345678"})
        self.assertEqual(code, 201)
        usuario = ret["usuario"]
        self.assertEqual(usuario["email"], "a@exemplo.com")
        self.assertNotIn("senha_hash", usuario)
        ret, code = self.executar("listar_usuarios")
        self.assertEqual(code, 200)
        self.assertEqual(len(ret["usuarios"]), 1)
        self.req.dados = {"nome": "Ana B"}
        self.api.g.usuario = dict(usuario, senha_hash=self.api.hash_senha("12345678"))
        ret, code = self.api.editar_usuario(usuario["id"])
        self.assertEqual((ret["usuario"]["nome"], code), ("Ana B", 200))
        self.req.dados = {"senha_atual": "12345678"}
        ret, code = self.api.apagar_usuario(usuario["id"])
        self.assertEqual(code, 200)

    def test_dias_semana_iso_na_criacao_de_materias(self):
        for invalido in (0, 8, "1", True, -1):
            with self.subTest(dia=invalido):
                resposta, codigo = self.executar("criar_materia", {
                    "nome": "Disciplina", "cor": "#123456",
                    "horarios": [{"dia_semana": invalido, "hora_inicio": "08:00", "hora_fim": "09:00"}],
                })
                self.assertEqual(codigo, 400)
                self.assertIn("dia_semana", resposta["erro"])
        self.assertEqual(len(self.api.supabase.dados["materias"]), 0)
        resposta, codigo = self.executar("criar_materia", {
            "nome": "Revisão", "cor": "#123456",
            "horarios": [{"dia_semana": 7, "hora_inicio": "08:00", "hora_fim": "09:00"}],
        })
        self.assertEqual(codigo, 201)
        self.assertEqual(resposta["materia"]["horarios_aula"][0]["dia_semana"], 7)

    def test_dia_semana_iso_criacao_e_edicao_horarios(self):
        materia = self.criar_materia()
        self.req.dados = {"dia_semana": 0, "hora_inicio": "10:00", "hora_fim": "11:00"}
        resposta, codigo = self.api.criar_horario(materia)
        self.assertEqual(codigo, 400)
        self.req.dados = {"dia_semana": 7, "hora_inicio": "10:00", "hora_fim": "11:00"}
        resposta, codigo = self.api.criar_horario(materia)
        self.assertEqual(codigo, 201)
        horario_id = resposta["horario"]["id"]
        self.req.dados = {"dia_semana": 8}
        resposta, codigo = self.api.editar_horario(horario_id)
        self.assertEqual(codigo, 400)
        self.req.dados = {"hora_inicio": "12:00"}
        resposta, codigo = self.api.editar_horario(horario_id)
        self.assertEqual(codigo, 400)
        self.req.dados = {"dia_semana": 1}
        resposta, codigo = self.api.editar_horario(horario_id)
        self.assertEqual(codigo, 200)
        self.assertEqual(resposta["horario"]["dia_semana"], 1)

    def test_horarios_rejeitam_formatos_invalidos(self):
        materia = self.criar_materia()
        for inicio, fim in (("12:00", "11:00"), ("11:00", "11:00"), ("errado", "12:00"), ("11:00+03:00", "12:00")):
            with self.subTest(inicio=inicio, fim=fim):
                self.req.dados = {"dia_semana": 2, "hora_inicio": inicio, "hora_fim": fim}
                _, codigo = self.api.criar_horario(materia)
                self.assertEqual(codigo, 400)

    def test_crud_materias_e_horarios(self):
        id_materia = self.criar_materia()
        ret, code = self.executar("listar_materias", args={"usuario_id": "1"})
        self.assertEqual((code, len(ret["materias"][0]["horarios_aula"])), (200, 1))
        self.req.dados = {"professor": "Marcos"}
        ret, code = self.api.editar_materia(id_materia)
        self.assertEqual((code, ret["materia"]["professor"]), (200, "Marcos"))
        ret, code = self.api.apagar_materia(id_materia)
        self.assertEqual(code, 200)
        self.assertFalse(self.api.supabase.dados["horarios_aula"])

    def test_crud_tarefas_e_exames(self):
        materia = self.criar_materia()
        ret, code = self.executar("criar_tarefa", {"materia_id": materia, "titulo": "Trabalho", "data_entrega": "2026-10-20T10:00:00"})
        self.assertEqual(code, 201)
        tarefa = ret["tarefa"]["id"]
        self.req.dados = {"status": "concluida"}
        ret, code = self.api.editar_tarefa(tarefa)
        self.assertEqual((code, ret["tarefa"]["status"]), (200, "concluida"))
        ret, code = self.executar("listar_tarefas", args={"usuario_id": "1"})
        self.assertEqual((code, len(ret["tarefas"])), (200, 1))
        ret, code = self.executar("criar_exame", {"materia_id": materia, "descricao": "Prova", "data_hora": "2026-10-22T14:00:00"})
        self.assertEqual(code, 201)
        exame = ret["exame"]["id"]
        self.req.dados = {"descricao": "Prova substitutiva"}
        ret, code = self.api.editar_exame(exame)
        self.assertEqual((code, ret["exame"]["descricao"]), (200, "Prova substitutiva"))
        ret, code = self.executar("listar_exames", args={"usuario_id": "1"})
        self.assertEqual((code, len(ret["exames"])), (200, 1))
        self.assertEqual(self.api.apagar_tarefa(tarefa)[1], 200)
        self.assertEqual(self.api.apagar_exame(exame)[1], 200)

    def test_jwt_login_e_identidade(self):
        _, status = self.executar("criar_usuario", {"nome": "Ana", "email": "ANA@example.com", "senha": "12345678"})
        self.assertEqual(status, 201)
        resp, status = self.executar("login", {"email": "ana@example.com", "senha": "errada"})
        self.assertEqual(status, 401)
        resp, status = self.executar("login", {"email": "ana@example.com", "senha": "12345678"})
        self.assertEqual(status, 200)
        token = resp["token"]
        self.assertEqual(resp["usuario"]["id"], 1)
        self.assertNotIn("senha_hash", resp["usuario"])
        self.req.path = "/api/auth/me"
        self.req.headers = {"Authorization": "Bearer " + token}
        self.req.method = "GET"
        self.assertIsNone(self.api.autenticar_requisicao())
        perfil, code = self.api.meu_perfil()
        self.assertEqual((code, perfil["usuario"]["email"]), (200, "ana@example.com"))

    def test_rotas_protegidas_e_jwt_invalido(self):
        self.req.path = "/api/materias"
        self.req.method = "GET"
        self.req.headers = {}
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        self.req.headers = {"Authorization": "Bearer token.falso.xxx"}
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        self.req.method = "OPTIONS"
        self.assertIsNone(self.api.autenticar_requisicao())
        self.req.method = "POST"
        self.req.path = "/api/usuarios"
        self.assertIsNone(self.api.autenticar_requisicao())

    def test_documentos_legais_podem_ser_lidos_antes_do_login(self):
        self.req.path = "/api/legal/documentos"
        self.req.method = "GET"
        self.req.headers = {}
        self.assertIsNone(self.api.autenticar_requisicao())
        self.req.method = "POST"
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)

    def test_vinculo_firebase_encerra_sessao_e_login_legados(self):
        self.executar("criar_usuario", {"nome": "Ana", "email": "ana@example.com", "senha": "12345678"})
        dados, _ = self.executar("login", {"email": "ana@example.com", "senha": "12345678"})
        self.api.supabase.table("usuarios").update({"firebase_uid": "uid-a"}).eq("id", 1).execute()
        self.req.path = "/api/auth/me"
        self.req.method = "GET"
        self.req.headers = {"Authorization": "Bearer " + dados["token"]}
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        self.assertEqual(self.executar("login", {"email": "ana@example.com", "senha": "12345678"})[1], 401)

    def test_sessao_firebase_confere_uid_e_revogacao_no_provedor(self):
        usuario = self.api.supabase.table("usuarios").insert({
            "id": 1, "nome": "Ana", "email": "ana@example.com", "firebase_uid": "uid-a", "senha_hash": None,
        }).execute().data[0]
        auth_time = int(datetime.now(timezone.utc).timestamp())
        token = self.api._criar_token(usuario, {"uid": "uid-a", "auth_time": auth_time})
        self.req.path = "/api/auth/me"
        self.req.method = "GET"
        self.req.headers = {"Authorization": "Bearer " + token}
        with patch("api.firebase_identity.verificar_sessao_firebase", return_value=True) as verificar:
            self.assertIsNone(self.api.autenticar_requisicao())
            verificar.assert_called_once_with("uid-a", auth_time)
        with patch("api.firebase_identity.verificar_sessao_firebase", return_value=False):
            self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        self.api.supabase.table("usuarios").update({"firebase_uid": "uid-b"}).eq("id", 1).execute()
        with patch("api.firebase_identity.verificar_sessao_firebase") as verificar:
            self.assertEqual(self.api.autenticar_requisicao()[1], 401)
            verificar.assert_not_called()

    def test_logout_revoga_token_no_servidor(self):
        self.executar("criar_usuario", {"nome": "Ana", "email": "ana@example.com", "senha": "12345678"})
        dados, _ = self.executar("login", {"email": "ana@example.com", "senha": "12345678"})
        self.req.path = "/api/auth/me"
        self.req.method = "GET"
        self.req.headers = {"Authorization": "Bearer " + dados["token"]}
        self.assertIsNone(self.api.autenticar_requisicao())
        resp, status = self.api.logout()
        self.assertEqual(status, 200)
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)

    def test_expiracao_assinatura_e_usuario_removido(self):
        self.executar("criar_usuario", {"nome": "Ana", "email": "ana@example.com", "senha": "12345678"})
        dados, _ = self.executar("login", {"email": "ana@example.com", "senha": "12345678"})
        self.req.path = "/api/auth/me"
        self.req.method = "GET"
        self.req.headers = {"Authorization": "Bearer " + dados["token"]}
        self.assertIsNone(self.api.autenticar_requisicao())
        claims = jwt.decode(
            dados["token"], self.api.JWT_SECRET, algorithms=["HS256"],
            audience=self.api.JWT_AUDIENCE, issuer=self.api.JWT_ISSUER
        )
        claims["exp"] = datetime.now(timezone.utc) - timedelta(minutes=2)
        expirado = jwt.encode(claims, self.api.JWT_SECRET, algorithm="HS256")
        self.req.headers = {"Authorization": "Bearer " + expirado}
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        claims["exp"] = datetime.now(timezone.utc) + timedelta(minutes=10)
        forjado = jwt.encode(claims, "chave-de-outro-servidor-com-mais-de-32-bytes", algorithm="HS256")
        self.req.headers = {"Authorization": "Bearer " + forjado}
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        self.req.headers = {"Authorization": "Bearer " + dados["token"]}
        self.api.supabase.table("usuarios").delete().eq("id", 1).execute()
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)

    def test_atualizar_recurso_alheio_e_token_fcm(self):
        materia = self.criar_materia()
        tarefa, _ = self.executar("criar_tarefa", {
            "materia_id": materia, "titulo": "Trabalho", "data_entrega": "2026-10-25T10:00:00"
        })
        self.executar("registrar_dispositivo", {"fcm_token": "segredo-fcm"})
        self.api.g.usuario_id = 2
        self.req.dados = {"status": "concluida"}
        self.assertEqual(self.api.editar_tarefa(tarefa["tarefa"]["id"])[1], 404)
        self.assertEqual(self.api.apagar_tarefa(tarefa["tarefa"]["id"])[1], 404)
        self.assertEqual(self.executar("remover_dispositivo", args={"fcm_token": "segredo-fcm"})[1], 200)
        self.assertEqual(len(self.api.supabase.dados["dispositivos"]), 1)
        self.api.g.usuario_id = 1

    def test_trocar_senha_invalida_token_antigo(self):
        self.executar("criar_usuario", {"nome": "Ana", "email": "ana@example.com", "senha": "12345678"})
        dados, _ = self.executar("login", {"email": "ana@example.com", "senha": "12345678"})
        self.req.path = "/api/auth/me"
        self.req.method = "GET"
        self.req.headers = {"Authorization": "Bearer " + dados["token"]}
        self.assertIsNone(self.api.autenticar_requisicao())
        self.req.dados = {"senha": "novaSenha88", "senha_atual": "12345678"}
        self.assertEqual(self.api.editar_usuario(1)[1], 200)
        self.assertEqual(self.api.autenticar_requisicao()[1], 401)
        self.assertEqual(self.executar("login", {"email": "ana@example.com", "senha": "novaSenha88"})[1], 200)

    def test_isolamento_entre_estudantes(self):
        materia = self.criar_materia()
        self.assertEqual(self.executar("listar_materias", args={"usuario_id": 2})[1], 403)
        self.assertEqual(self.executar("criar_materia", {"usuario_id": 2, "nome": "X", "cor": "#fff"})[1], 403)
        self.assertEqual(self.executar("enviar_notificacao", {"usuario_id": 2, "titulo": "X", "corpo": "Y"})[1], 403)
        self.api.g.usuario_id = 2
        self.assertEqual(self.api.editar_materia(materia)[1], 404)
        self.assertEqual(self.api.apagar_materia(materia)[1], 404)
        self.assertEqual(self.executar("criar_tarefa", {"materia_id": materia, "titulo": "X", "data_entrega": "2026-10-25T10:00:00"})[1], 404)
        self.req.dados = {"dia_semana": 2, "hora_inicio": "10:00", "hora_fim": "11:00"}
        self.assertEqual(self.api.criar_horario(materia)[1], 404)
        self.assertEqual(self.api.apagar_usuario(1)[1], 403)
        self.api.g.usuario_id = 1

    def test_calendario_agrega_eventos_e_aulas(self):
        materia = self.criar_materia()
        self.api.supabase.table("tarefas").insert({"materia_id": materia, "titulo": "Lista", "data_entrega": "2026-10-23T10:00:00", "status": "pendente"}).execute()
        self.api.supabase.table("exames").insert({"materia_id": materia, "data_hora": "2026-10-22T10:00:00", "descricao": "Exame"}).execute()
        ret, code = self.executar("consultar_calendario", args={"usuario_id": "1", "inicio": "2026-10-21", "fim": "2026-10-30"})
        self.assertEqual(code, 200)
        self.assertEqual([ev["tipo"] for ev in ret["eventos"]], ["exame", "tarefa"])
        self.assertEqual(len(ret["aulas_semanais"]), 1)

    def test_calendario_rejeita_intervalo_invalido(self):
        _, code = self.executar("consultar_calendario", args={"usuario_id": "1", "inicio": "2026-10-30", "fim": "2026-10-21"})
        self.assertEqual(code, 400)
        _, code = self.executar("consultar_calendario", args={"usuario_id": "1", "inicio": "2026-01-01", "fim": "2026-12-31"})
        self.assertEqual(code, 400)
        _, code = self.executar("consultar_calendario", args={"usuario_id": "1", "inicio": "sem-data", "fim": "2026-10-21"})
        self.assertEqual(code, 400)

    def test_progresso_por_materia_e_geral(self):
        materia = self.criar_materia()
        self.api.supabase.table("tarefas").insert([
            {"materia_id": materia, "titulo": "A", "status": "concluida", "data_entrega": "2026-10-20T10:00:00"},
            {"materia_id": materia, "titulo": "B", "status": "pendente", "data_entrega": "2026-10-20T10:00:00"},
            {"materia_id": materia, "titulo": "C", "status": "pendente", "data_entrega": "2026-10-25T10:00:00"},
        ]).execute()
        with patch.object(self.api, "agora_do_usuario", return_value="2026-10-21T12:00:00"):
            ret, code = self.executar("consultar_progresso", args={"usuario_id": "1"})
        self.assertEqual(code, 200)
        self.assertEqual((ret["total"], ret["concluidas"], ret["pendentes"], ret["vencidas"]), (3, 1, 2, 1))
        self.assertEqual(ret["percentual"], 33.33)

    def test_progresso_vazio(self):
        ret, code = self.executar("consultar_progresso", args={"usuario_id": "1"})
        self.assertEqual((code, ret["percentual"], ret["total"]), (200, 0, 0))

    def test_tarefa_e_prova_sem_materia_aparecem_somente_para_o_titular(self):
        tarefa = self.api.supabase.table("tarefas").insert({
            "usuario_id": 1, "materia_id": None, "titulo": "Tarefa avulsa",
            "status": "concluida", "data_entrega": "2026-11-18T12:00:00",
        }).execute().data[0]
        exame = self.api.supabase.table("exames").insert({
            "usuario_id": 1, "materia_id": None, "descricao": "Prova avulsa",
            "data_hora": "2026-11-18T13:00:00",
        }).execute().data[0]
        alheia = self.api.supabase.table("tarefas").insert({
            "usuario_id": 2, "materia_id": None, "titulo": "De outra conta",
            "status": "pendente", "data_entrega": "2026-11-18T14:00:00",
        }).execute().data[0]
        tarefas, status = self.executar("listar_tarefas")
        self.assertEqual(status, 200)
        self.assertEqual([t["id"] for t in tarefas["tarefas"]], [tarefa["id"]])
        exames, status = self.executar("listar_exames")
        self.assertEqual(status, 200)
        self.assertEqual([e["id"] for e in exames["exames"]], [exame["id"]])
        calendario, status = self.executar("consultar_calendario", args={
            "inicio": "2026-11-18", "fim": "2026-11-18",
        })
        self.assertEqual(status, 200)
        self.assertEqual([(e["tipo"], e["id"]) for e in calendario["eventos"]], [
            ("tarefa", tarefa["id"]), ("exame", exame["id"]),
        ])
        self.assertTrue(all(e["materia_nome"] == "Sem matéria" for e in calendario["eventos"]))
        progresso, status = self.executar("consultar_progresso")
        self.assertEqual((status, progresso["total"], progresso["concluidas"]), (200, 1, 1))
        self.assertIsNone(progresso["por_materia"][0]["materia_id"])

        self.req.dados = {"titulo": "Tentativa alheia"}
        self.assertEqual(self.api.editar_tarefa(alheia["id"])[1], 404)
        self.api.g.usuario_id = 2
        tarefas, status = self.executar("listar_tarefas")
        self.assertEqual(status, 200)
        self.assertEqual([t["id"] for t in tarefas["tarefas"]], [alheia["id"]])

    def test_registro_transferencia_e_remocao_dispositivo(self):
        ret, code = self.executar("registrar_dispositivo", {"usuario_id": 1, "fcm_token": "token-1"})
        self.assertEqual(code, 201)
        ret, code = self.executar("registrar_dispositivo", {"usuario_id": 2, "fcm_token": "token-1"})
        self.assertEqual(code, 403)
        self.assertEqual(len(self.api.supabase.dados["dispositivos"]), 1)
        self.assertEqual(self.api.supabase.dados["dispositivos"][0]["usuario_id"], 1)
        ret, code = self.executar("remover_dispositivo", args={"fcm_token": "token-1"})
        self.assertEqual(code, 200)
        self.assertEqual(self.api.supabase.dados["dispositivos"], [])

    def test_notificacao_simulada_nao_usa_firebase(self):
        self.api.supabase.table("dispositivos").insert({"usuario_id": 1, "fcm_token": "token-1"}).execute()
        with patch.object(self.api, "enviar_push", return_value=(True, "enviada")) as enviar:
            ret, code = self.executar("enviar_notificacao", {"usuario_id": 1, "titulo": "Olá", "corpo": "Estude!"})
        self.assertEqual((code, ret["enviadas"]), (200, 1))
        enviar.assert_called_once_with("token-1", "Olá", "Estude!", None, usuario_id=1)

    def test_criacao_offline_repassa_a_chave_e_mantem_o_formato(self):
        materia = self.criar_materia()
        chave = "f7a5bf8c-df1f-4d5e-bb9b-9624834e6061"
        campos = {"materia_id": materia, "titulo": "Lista", "data_entrega": "2026-11-10T13:30:00"}
        resultado = types.SimpleNamespace(data={"status": 200, "registro": {"id": 15, **campos}})
        self.req.headers = {"Idempotency-Key": chave}
        with patch.object(self.api.supabase, "rpc") as rpc:
            rpc.return_value.execute.return_value = resultado
            resposta, status = self.executar("criar_tarefa", campos)
        self.assertEqual((resposta, status), ({"tarefa": resultado.data["registro"]}, 200))
        rpc.assert_called_once_with("criar_registro_offline", {
            "p_usuario_id": 1, "p_chave": chave, "p_tabela": "tarefas",
            "p_dados": campos, "p_horarios": [],
        })
        self.assertEqual(self.api.supabase.dados["tarefas"], [])
        self.req.headers = {"Idempotency-Key": "invalida"}
        self.assertEqual(self.executar("criar_tarefa", campos)[1], 400)

    def test_escrita_offline_recusa_versao_antiga(self):
        materia = self.criar_materia()
        versao = "2026-11-01T13:00:00"
        tarefa = self.api.supabase.table("tarefas").insert({
            "materia_id": materia, "titulo": "Lista", "atualizado_em": versao,
        }).execute().data[0]["id"]
        self.req.headers = {"X-Registro-Versao": versao}
        self.req.dados = {"titulo": "Lista revisada"}
        resposta, status = self.api.editar_tarefa(tarefa)
        self.assertEqual(status, 200)
        self.assertNotEqual(resposta["tarefa"]["atualizado_em"], versao)
        self.assertEqual(self.api.editar_tarefa(tarefa)[1], 409)
        self.assertEqual(self.api.apagar_tarefa(tarefa)[1], 409)
        self.req.headers = {"X-Registro-Versao": resposta["tarefa"]["atualizado_em"]}
        self.assertEqual(self.api.apagar_tarefa(tarefa)[1], 200)
        self.assertEqual(self.api.apagar_tarefa(tarefa)[1], 404)

    def test_validacao_de_entrada(self):
        self.assertEqual(self.executar("criar_usuario", {"nome": "A", "email": "a@x.com", "senha": "123"})[1], 400)
        self.assertEqual(self.executar("criar_tarefa", {"titulo": "Sem matéria"})[1], 400)
        self.assertEqual(self.executar("listar_exames", args={"usuario_id": 2})[1], 403)
        self.assertEqual(self.executar("consultar_progresso", args={"usuario_id": 2})[1], 403)
        self.assertEqual(self.executar("registrar_dispositivo")[1], 400)

    def test_limite_de_materias_free_e_acesso_pro(self):
        self.api.g.usuario["plano"] = "free"
        self.api.supabase.table("materias").insert([
            {"usuario_id": 1, "nome": f"Matéria {i}", "cor": "#ABCDEF"} for i in range(5)
        ]).execute()
        corpo = {"nome": "Sexta matéria", "cor": "#ABCDEF"}
        resposta, status = self.executar("criar_materia", corpo)
        self.assertEqual((status, resposta["plano_necessario"]), (402, "premium"))
        self.assertEqual(len(self.api.supabase.dados["materias"]), 5)

        self.api.g.usuario["plano"] = "pro"
        resposta, status = self.executar("criar_materia", corpo)
        self.assertEqual((status, resposta["materia"]["nome"]), (201, "Sexta matéria"))

    def test_assinatura_simulada_atualiza_plano_e_conserva_materias(self):
        usuario = self.api.supabase.table("usuarios").insert({
            "id": 1, "nome": "Ana", "email": "ana@example.com",
        }).execute().data[0]
        self.api.g.usuario = usuario
        resposta, status = self.executar("consultar_assinatura")
        self.assertEqual((status, resposta["plano"], resposta["limite_materias"]), (200, "free", 5))

        resposta, status = self.executar("assinar_premium")
        self.assertEqual((status, resposta["usuario"]["plano"]), (200, "premium"))
        self.api.g.usuario = resposta["usuario"]
        self.api.supabase.table("materias").insert({"usuario_id": 1, "nome": "Matéria"}).execute()
        assinatura, status = self.executar("consultar_assinatura")
        self.assertEqual(status, 200)
        self.assertIsNone(assinatura["limite_materias"])
        self.assertIsNotNone(assinatura["premium_desde"])

        resposta, status = self.executar("cancelar_premium")
        self.assertEqual((status, resposta["usuario"]["plano"]), (200, "free"))
        self.assertEqual(len(self.api.supabase.dados["materias"]), 1)


if __name__ == "__main__":
    unittest.main()

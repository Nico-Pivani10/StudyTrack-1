"""Contrato HTTP do aplicativo e importação dos dados legados do Firestore."""

import base64
import binascii
from datetime import datetime, timezone
from time import monotonic

from api.firebase_identity import firebase_app, verificar_identidade
from api.legal import DOCUMENTOS, validar_aceite


TIPOS = {"materias", "tareas", "examenes", "sesionesEstudio", "notificaciones"}
MAX_FOTO = 150 * 1024


def converter_firestore(valor):
    if isinstance(valor, datetime):
        return valor.astimezone(timezone.utc).isoformat()
    if isinstance(valor, bytes):
        return base64.b64encode(valor).decode("ascii")
    if isinstance(valor, dict):
        return {chave: converter_firestore(item) for chave, item in valor.items()}
    if isinstance(valor, (list, tuple)):
        return [converter_firestore(item) for item in valor]
    return valor


def validar_dados(tipo, dados, *, parcial=False):
    if not isinstance(dados, dict):
        raise ValueError("envie um objeto JSON")
    if tipo == "perfil" and "fotoPerfilBytes" in dados and dados["fotoPerfilBytes"] is not None:
        try:
            foto = base64.b64decode(dados["fotoPerfilBytes"], validate=True)
        except (TypeError, ValueError, binascii.Error):
            raise ValueError("fotoPerfilBytes deve conter base64 válido") from None
        if len(foto) > MAX_FOTO:
            raise ValueError("a foto deve ter até 150 KiB")
    if tipo in ("materias", "tareas", "examenes"):
        campo = "nombre" if tipo == "materias" else "titulo"
        if (not parcial or campo in dados) and (not isinstance(dados.get(campo), str) or not dados[campo].strip()):
            raise ValueError(f"{campo} é obrigatório")
    for campo in ("fecha", "fechaEntrega", "creadaEn", "actualizadoEn"):
        if campo in dados and dados[campo] is not None:
            try:
                if not isinstance(dados[campo], str):
                    raise ValueError()
                datetime.fromisoformat(dados[campo].replace("Z", "+00:00"))
            except ValueError:
                raise ValueError(f"{campo} deve ser uma data ISO 8601") from None
    data_obrigatoria = {"tareas": "fechaEntrega", "examenes": "fecha", "sesionesEstudio": "fecha"}.get(tipo)
    if data_obrigatoria and not parcial and not dados.get(data_obrigatoria):
        raise ValueError(f"{data_obrigatoria} é obrigatória")
    if tipo == "sesionesEstudio" and (not parcial or "minutos" in dados) and (type(dados.get("minutos")) is not int or not 1 <= dados["minutos"] <= 1440):
        raise ValueError("minutos deve estar entre 1 e 1440")
    if "completada" in dados and type(dados["completada"]) is not bool:
        raise ValueError("completada deve ser booleano")
    if "minutosAntes" in dados and (type(dados["minutosAntes"]) is not int or not 0 <= dados["minutosAntes"] <= 43200):
        raise ValueError("minutosAntes deve estar entre 0 e 43200")
    if tipo == "perfil":
        if "plan" in dados and dados["plan"] not in ("gratis", "free", "pro", "premium"):
            raise ValueError("plano inválido")
        if "metaSemanalDias" in dados and (type(dados["metaSemanalDias"]) is not int or not 1 <= dados["metaSemanalDias"] <= 7):
            raise ValueError("a meta deve estar entre 1 e 7 dias")
    return dados


def registrar_mobile(app, supabase, criar_token):
    from flask import g, jsonify, request

    def rpc(nome, dados):
        return supabase.rpc(nome, {"p_usuario_id": g.usuario_id, **dados}).execute().data

    def resposta(resultado):
        return jsonify({k: v for k, v in resultado.items() if k != "status"}), resultado.get("status", 200)

    def falha(mensagem):
        app.logger.exception(mensagem)
        return jsonify(erro="não foi possível concluir a operação"), 503

    @app.route("/api/auth/firebase", methods=["POST"])
    def autenticar_firebase():
        from firebase_admin import auth

        dados = request.get_json(silent=True)
        token = dados.get("id_token") if isinstance(dados, dict) else None
        if not isinstance(token, str) or not 20 <= len(token) <= 20000:
            return jsonify(erro="envie o id_token do Firebase"), 400
        aceitou, erro_aceite = validar_aceite(dados.get("aceite"))
        if erro_aceite:
            return jsonify(erro_aceite[0]), erro_aceite[1]
        try:
            identidade = verificar_identidade(token)
        except (auth.InvalidIdTokenError, auth.RevokedIdTokenError, auth.UserDisabledError, auth.UserNotFoundError):
            return jsonify(erro="sessão Firebase inválida ou encerrada"), 401
        except Exception:
            return falha("Falha ao verificar identidade Firebase")
        email = identidade.get("email")
        if not isinstance(email, str) or not email:
            return jsonify(erro="a conta Firebase precisa ter um e-mail"), 400
        try:
            resultado = supabase.rpc("autenticar_firebase_com_aceite", {
                "p_uid": identidade["uid"], "p_email": email.lower(),
                "p_nome": identidade.get("name") or email.split("@")[0],
                "p_documentos": DOCUMENTOS, "p_aceitou": aceitou,
            }).execute().data
            if resultado.get("status") != 200:
                return resposta(resultado)
            usuario = resultado["usuario"]
            return jsonify(
                token=criar_token(usuario, identidade), tipo="Bearer", expira_em_segundos=3600,
                usuario={k: v for k, v in usuario.items() if k != "senha_hash"},
            ), 200
        except Exception:
            return falha("Falha ao vincular identidade Firebase")

    @app.route("/api/mobile/estado", methods=["GET"])
    def estado():
        try:
            return jsonify(rpc("mobile_estado", {})), 200
        except Exception:
            return falha("Falha ao consultar estado mobile")

    @app.route("/api/auth/firebase/vincular", methods=["POST"])
    def vincular_conta_existente():
        from firebase_admin import auth

        if getattr(g, "jwt_claims", {}).get("origem") == "firebase":
            return jsonify(erro="entre com a senha da conta da API para confirmar o vínculo"), 403
        agora = int(datetime.now(timezone.utc).timestamp())
        emitido = getattr(g, "jwt_claims", {}).get("iat")
        if type(emitido) is not int or not 0 <= agora - emitido <= 300:
            return jsonify(erro="confirme novamente a senha da conta da API para vincular"), 401
        dados = request.get_json(silent=True)
        token = dados.get("id_token") if isinstance(dados, dict) else None
        if not isinstance(token, str) or not 20 <= len(token) <= 20000:
            return jsonify(erro="envie o id_token do Firebase"), 400
        aceitou, erro_aceite = validar_aceite(dados.get("aceite"))
        if erro_aceite:
            return jsonify(erro_aceite[0]), erro_aceite[1]
        try:
            identidade = verificar_identidade(token)
        except (auth.InvalidIdTokenError, auth.RevokedIdTokenError, auth.UserDisabledError, auth.UserNotFoundError):
            return jsonify(erro="sessão Firebase inválida ou encerrada"), 401
        except Exception:
            return falha("Falha ao verificar identidade para vínculo")
        if (identidade.get("email") or "").lower() != g.usuario.get("email", "").lower():
            return jsonify(erro="confirme a conta da API com o mesmo e-mail da conta Firebase"), 409
        autenticado = identidade.get("auth_time")
        if type(autenticado) is not int or not 0 <= agora - autenticado <= 300:
            return jsonify(erro="entre novamente pelo Firebase para confirmar o vínculo"), 401
        try:
            resultado = rpc("vincular_firebase_com_aceite", {
                "p_uid": identidade["uid"], "p_senha_hash": g.usuario.get("senha_hash"),
                "p_documentos": DOCUMENTOS, "p_aceitou": aceitou,
            })
            if resultado.get("status") != 200:
                return resposta(resultado)
            usuario = resultado["usuario"]
            return jsonify(
                token=criar_token(usuario, identidade), tipo="Bearer", expira_em_segundos=3600,
                usuario={k: v for k, v in usuario.items() if k != "senha_hash"},
            ), 200
        except Exception:
            return falha("Falha ao confirmar vínculo da conta existente")

    @app.route("/api/mobile/perfil", methods=["PATCH"])
    def perfil():
        try:
            dados = validar_dados("perfil", request.get_json(silent=True))
            return resposta(rpc("mobile_perfil", {"p_dados": dados, "p_importar": False}))
        except ValueError as erro:
            return jsonify(erro=str(erro)), 400
        except Exception:
            return falha("Falha ao atualizar perfil mobile")

    @app.route("/api/mobile/<string:tipo>/<string:registro_id>", methods=["PUT", "PATCH", "DELETE"])
    def gravar(tipo, registro_id):
        if tipo not in TIPOS or not 1 <= len(registro_id) <= 200 or "/" in registro_id:
            return jsonify(erro="recurso inválido"), 400
        try:
            if request.method == "DELETE":
                return resposta(rpc("mobile_excluir", {"p_tipo": tipo, "p_id": registro_id}))
            dados = validar_dados(tipo, request.get_json(silent=True), parcial=True)
            return resposta(rpc("mobile_gravar", {
                "p_tipo": tipo, "p_id": registro_id, "p_dados": dados, "p_importar": False,
                "p_atualizar": request.method == "PATCH",
            }))
        except ValueError as erro:
            return jsonify(erro=str(erro)), 400
        except Exception:
            return falha("Falha na escrita mobile")

    @app.route("/api/mobile/importar", methods=["POST"])
    def importar():
        uid = g.usuario.get("firebase_uid")
        if not uid:
            return jsonify(erro="entre usando Firebase para importar seus dados"), 403
        if g.usuario.get("mobile_importado_em"):
            return jsonify(importado=True, ja_importado=True, contagens={}), 200
        try:
            from firebase_admin import firestore

            inicio = monotonic()
            origem = firestore.client(app=firebase_app()).collection("usuarios").document(uid)
            contagens = {tipo: 0 for tipo in TIPOS}
            progresso = (supabase.table("usuarios").select("mobile_importacao")
                         .eq("id", g.usuario_id).execute().data)[0].get("mobile_importacao") or {}
            snapshot = origem.get()
            dados_perfil = converter_firestore(snapshot.to_dict() or {})
            validar_dados("perfil", dados_perfil)
            resultado = rpc("mobile_perfil", {"p_dados": dados_perfil, "p_importar": True})
            if resultado.get("status") != 200:
                return resposta(resultado)
            # Matérias vêm antes das atividades para preservar as referências de origem.
            for tipo in ("materias", "tareas", "examenes", "sesionesEstudio", "notificaciones"):
                cursor = progresso.get(tipo, {})
                if cursor.get("concluido"):
                    continue
                colecao = origem.collection(tipo)
                consulta = colecao.order_by("__name__")
                if cursor.get("ultimo"):
                    consulta = consulta.start_after({"__name__": colecao.document(cursor["ultimo"])})
                restantes = 20 - sum(contagens.values())
                documentos = list(consulta.limit(restantes).stream())
                for documento in documentos:
                    dados = converter_firestore(documento.to_dict())
                    validar_dados(tipo, dados)
                    resultado = rpc("mobile_gravar", {
                        "p_tipo": tipo, "p_id": documento.id, "p_dados": dados, "p_importar": True,
                    })
                    if resultado.get("status") not in (200, 201):
                        return resposta(resultado)
                    contagens[tipo] += 1
                    if sum(contagens.values()) >= 20 or monotonic() - inicio >= 8:
                        return jsonify(importado=False, continuar=True, contagens=contagens), 200
                rpc("mobile_finalizar_tipo", {"p_tipo": tipo})
            supabase.table("usuarios").update({
                "mobile_importado_em": datetime.now(timezone.utc).isoformat(),
            }).eq("id", g.usuario_id).execute()
            return jsonify(importado=True, contagens=contagens), 200
        except ValueError as erro:
            return jsonify(erro=f"um registro legado precisa de correção: {erro}", importado=False), 422
        except Exception:
            return falha("Falha na importação mobile; a operação pode ser retomada")

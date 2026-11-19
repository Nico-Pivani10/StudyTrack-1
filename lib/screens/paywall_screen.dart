import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/app_data.dart';
import '../services/studytrack_repository.dart';

// =====================================================
// MODELO PARA DESCRIBIR LOS BENEFICIOS
// =====================================================

class _BeneficioPlan {
  final String titulo;
  final String descripcion;

  const _BeneficioPlan({required this.titulo, required this.descripcion});
}

// =====================================================
// PAYWALL DE STUDYTRACK
// =====================================================
//
// Planes:
// - Gratis: US$0
// - Pro: US$10 por mes
// - Premium: US$20 por mes
//
// Compatible con español y portugués brasileño.
//
// Las compras son simuladas.
// Los beneficios exclusivos de Pro y Premium
// todavía son propuestas de desarrollo.
//
// =====================================================

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // =====================================================
  // COLORES DE STUDYTRACK
  // =====================================================

  static const Color bordo = Color(0xFF670810);
  static const Color coral = Color(0xFFE57373);

  bool _esOscuro(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _colorAcento(BuildContext context) {
    return _esOscuro(context) ? coral : bordo;
  }

  Color _textoSobreAcento(BuildContext context) {
    return _esOscuro(context) ? Colors.black : Colors.white;
  }

  Color _fondoIcono(BuildContext context) {
    return _esOscuro(context)
        ? coral.withValues(alpha: 0.16)
        : const Color(0xFFF4E9EB);
  }

  Color _fondoTarjeta(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  Color _textoPrincipal(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _textoSecundario(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Color _bordeTarjeta(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  // =====================================================
  // SISTEMA DE TRADUCCIONES
  // =====================================================

  // Detecta el idioma establecido en MaterialApp.
  // No necesita agregar claves a los archivos ARB.

  String _t(String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;

    return idioma == 'pt' ? pt : es;
  }

  // =====================================================
  // ESTADO DEL PAYWALL
  // =====================================================

  bool cargando = true;
  bool guardando = false;
  bool errorCarga = false;

  String planActual = 'gratis';
  String planSeleccionado = 'gratis';
  String metodoPago = 'tarjeta';

  @override
  void initState() {
    super.initState();
    cargarPlanActual();
  }

  // =====================================================
  // CARGAR PLAN DESDE LA API
  // =====================================================

  Future<void> cargarPlanActual() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        errorCarga = true;
      });

      return;
    }

    try {
      final doc = await StudyTrackRepository(usuario.uid).usuario.get();

      if (!mounted) return;

      final data = doc.data();

      final valor = (data?['plan'] ?? 'gratis').toString();

      // Compatibilidad con la versión anterior.
      final plan = valor == 'free' ? 'gratis' : valor;

      setState(() {
        planActual = ['gratis', 'pro', 'premium'].contains(plan)
            ? plan
            : 'gratis';

        planSeleccionado = planActual;
        cargando = false;
      });
    } catch (error) {
      debugPrint('Error cargando plan: $error');

      if (!mounted) return;

      setState(() {
        cargando = false;
        errorCarga = true;
      });

      mostrarMensaje(
        _t('No se pudo cargar el plan.', 'Não foi possível carregar o plano.'),
      );
    }
  }

  // =====================================================
  // MOSTRAR MENSAJES
  // =====================================================

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: bordo));
  }

  // =====================================================
  // GUARDAR PLAN MEDIANTE LA API
  // =====================================================

  Future<void> aplicarPlan() async {
    if (guardando || cargando || errorCarga) return;

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      mostrarMensaje(
        _t('Debes iniciar sesión.', 'Você precisa entrar na sua conta.'),
      );

      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      // El repositorio guarda el plan mediante la API.
      // No se realiza ningún cobro real.

      await StudyTrackRepository(usuario.uid).usuario.set({
        'plan': planSeleccionado,
        'metodoPagoSimulado': planSeleccionado == 'gratis' ? null : metodoPago,
        'planActualizadoEn': AppFieldValue.serverTimestamp(),
      }, merge: true);

      if (!mounted) return;

      setState(() {
        planActual = planSeleccionado;
      });

      mostrarMensaje(
        _t(
          'Plan "${nombrePlan(planSeleccionado)}" '
              'aplicado correctamente.',
          'Plano "${nombrePlan(planSeleccionado)}" '
              'aplicado com sucesso.',
        ),
      );
    } catch (error) {
      debugPrint('Error guardando plan: $error');

      if (!mounted) return;

      mostrarMensaje(
        _t('No se pudo guardar el plan.', 'Não foi possível salvar o plano.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  // =====================================================
  // NOMBRES Y PRECIOS
  // =====================================================

  String nombrePlan(String plan) {
    switch (plan) {
      case 'pro':
        return 'Pro';

      case 'premium':
        return 'Premium';

      default:
        return _t('Gratis', 'Grátis');
    }
  }

  String precioPlan(String plan) {
    switch (plan) {
      case 'pro':
        return 'US\$10';

      case 'premium':
        return 'US\$20';

      default:
        return 'US\$0';
    }
  }

  // =====================================================
  // SUBTÍTULOS DE LOS PLANES
  // =====================================================

  String _subtituloPlan(String plan) {
    switch (plan) {
      case 'pro':
        return _t(
          'Organización y productividad',
          'Organização e produtividade',
        );

      case 'premium':
        return _t(
          'Seguimiento académico avanzado',
          'Acompanhamento acadêmico avançado',
        );

      default:
        return _t('Las herramientas esenciales', 'As ferramentas essenciais');
    }
  }

  // =====================================================
  // DESCRIPCIÓN GENERAL DE LOS PLANES
  // =====================================================

  String _descripcionPlan(String plan) {
    switch (plan) {
      case 'pro':
        return _t(
          'Pensado para estudiantes que quieren '
              'planificar mejor sus semanas, organizar '
              'sus prioridades y llevar un seguimiento '
              'más detallado de sus hábitos de estudio.',
          'Pensado para estudantes que desejam '
              'planejar melhor suas semanas, organizar '
              'suas prioridades e acompanhar seus '
              'hábitos de estudo com mais detalhes.',
        );

      case 'premium':
        return _t(
          'Diseñado como la experiencia más completa '
              'de StudyTrack. Su objetivo es ayudar '
              'a analizar el rendimiento académico, '
              'anticipar dificultades y mejorar '
              'la distribución del tiempo.',
          'Desenvolvido como a experiência mais completa '
              'do StudyTrack. Seu objetivo é ajudar '
              'a analisar o desempenho acadêmico, '
              'antecipar dificuldades e melhorar '
              'a distribuição do tempo.',
        );

      default:
        return _t(
          'Ideal para organizar tu rutina académica '
              'sin complicaciones. Reuní tus materias, '
              'tareas, exámenes y actividades en una '
              'misma aplicación y consultá todo '
              'cuando lo necesites.',
          'Ideal para organizar sua rotina acadêmica '
              'sem complicações. Reúna disciplinas, '
              'tarefas, provas e atividades em um '
              'mesmo aplicativo e consulte tudo '
              'quando precisar.',
        );
    }
  }

  // =====================================================
  // A QUIÉN VA DIRIGIDO CADA PLAN
  // =====================================================

  String _idealPara(String plan) {
    switch (plan) {
      case 'pro':
        return _t(
          'Estudiantes con varias materias y '
              'entregas que buscan una planificación '
              'más organizada.',
          'Estudantes com várias disciplinas e '
              'prazos que buscam um planejamento '
              'mais organizado.',
        );

      case 'premium':
        return _t(
          'Estudiantes que desean analizar su '
              'progreso y aprovechar mejor '
              'cada sesión de estudio.',
          'Estudantes que desejam analisar seu '
              'progresso e aproveitar melhor '
              'cada sessão de estudo.',
        );

      default:
        return _t(
          'Estudiantes que necesitan administrar '
              'sus actividades académicas diarias.',
          'Estudantes que precisam gerenciar '
              'suas atividades acadêmicas diárias.',
        );
    }
  }

  // =====================================================
  // BENEFICIOS DEL PLAN GRATIS
  // =====================================================

  // Estas funcionalidades ya forman parte
  // de la aplicación actual.

  List<_BeneficioPlan> _beneficiosGratis() {
    return [
      _BeneficioPlan(
        titulo: _t('Gestión de materias', 'Gerenciamento de disciplinas'),
        descripcion: _t(
          'Registrá tus materias, docentes y '
              'descripciones para mantener organizada '
              'la información de tus cursos.',
          'Cadastre suas disciplinas, professores '
              'e descrições para manter organizadas '
              'as informações dos seus cursos.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Administración de tareas', 'Gerenciamento de tarefas'),
        descripcion: _t(
          'Creá actividades con fecha y hora de '
              'entrega, consultá las pendientes '
              'y marcá las que hayas completado.',
          'Crie atividades com data e horário '
              'de entrega, consulte as pendentes '
              'e marque as que já concluiu.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Calendario académico', 'Calendário acadêmico'),
        descripcion: _t(
          'Visualizá tus tareas y exámenes por fecha. '
              'Podés consultar el calendario por '
              'mes o por semana y registrar exámenes.',
          'Visualize suas tarefas e provas por data. '
              'Você pode consultar o calendário '
              'por mês ou semana e cadastrar provas.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Recordatorios de tareas', 'Lembretes de tarefas'),
        descripcion: _t(
          'Elegí la anticipación de los recordatorios '
              'y recibí avisos locales en Android '
              'cuando la plataforma lo permita.',
          'Escolha a antecedência dos lembretes '
              'e receba avisos locais no Android '
              'quando a plataforma permitir.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Panel de progreso académico',
          'Painel de progresso acadêmico',
        ),
        descripcion: _t(
          'Consultá un resumen de tus materias, '
              'tareas, próximas actividades '
              'y objetivos de estudio.',
          'Consulte um resumo das disciplinas, '
              'tarefas, próximas atividades '
              'e metas de estudo.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Herramientas GPS y QR', 'Ferramentas de GPS e QR'),
        descripcion: _t(
          'Buscá destinos, consultá rutas '
              'en el mapa y escaneá códigos QR '
              'desde la aplicación.',
          'Pesquise destinos, consulte rotas '
              'no mapa e leia códigos QR '
              'pelo aplicativo.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Historial de notificaciones', 'Histórico de notificações'),
        descripcion: _t(
          'Consultá los avisos registrados '
              'y marcá las notificaciones '
              'como leídas.',
          'Consulte os avisos registrados '
              'e marque as notificações '
              'como lidas.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Reloj académico simulado', 'Relógio acadêmico simulado'),
        descripcion: _t(
          'Visualizá tu próxima tarea y el tiempo '
              'que queda para su entrega en '
              'la interfaz Wearable de StudyTrack.',
          'Visualize sua próxima tarefa e o tempo '
              'restante até a entrega na interface '
              'Wearable do StudyTrack.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Perfil y preferencias', 'Perfil e preferências'),
        descripcion: _t(
          'Administrá tu información personal '
              'y académica. Elegí el idioma, '
              'el tema y las preferencias de la app.',
          'Gerencie suas informações pessoais '
              'e acadêmicas. Escolha o idioma, '
              'o tema e as preferências do aplicativo.',
        ),
      ),
    ];
  }

  // =====================================================
  // BENEFICIOS PREVISTOS PARA PRO
  // =====================================================

  // Este plan incluye todas las funciones Gratis,
  // más las siguientes propuestas de desarrollo.

  List<_BeneficioPlan> _beneficiosPro() {
    return [
      _BeneficioPlan(
        titulo: _t('Recordatorios avanzados', 'Lembretes avançados'),
        descripcion: _t(
          'Configurar varios recordatorios para '
              'una misma actividad y ajustar '
              'la anticipación según su importancia.',
          'Configurar vários lembretes para '
              'uma mesma atividade e ajustar '
              'a antecedência conforme sua importância.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Planificador semanal de estudio',
          'Planejador semanal de estudos',
        ),
        descripcion: _t(
          'Organizar sesiones de estudio por '
              'día y materia para distribuir '
              'mejor el tiempo disponible.',
          'Organizar sessões de estudo por '
              'dia e disciplina para distribuir '
              'melhor o tempo disponível.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Prioridades y filtros de tareas',
          'Prioridades e filtros de tarefas',
        ),
        descripcion: _t(
          'Clasificar actividades por urgencia, '
              'materia y fecha de entrega para '
              'identificar qué conviene hacer primero.',
          'Classificar atividades por urgência, '
              'disciplina e prazo para identificar '
              'o que deve ser feito primeiro.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Estadísticas básicas de estudio',
          'Estatísticas básicas de estudo',
        ),
        descripcion: _t(
          'Consultar resúmenes semanales '
              'de tiempo estudiado, tareas completadas '
              'y actividades pendientes.',
          'Consultar resumos semanais '
              'do tempo estudado, tarefas concluídas '
              'e atividades pendentes.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Metas académicas personalizadas',
          'Metas acadêmicas personalizadas',
        ),
        descripcion: _t(
          'Definir objetivos de estudio por '
              'semana y revisar el avance '
              'de cada uno.',
          'Definir objetivos de estudo por '
              'semana e acompanhar '
              'o progresso de cada um.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Panel más personalizable', 'Painel mais personalizável'),
        descripcion: _t(
          'Elegir qué indicadores y secciones '
              'mostrar primero en el Dashboard '
              'según tus necesidades.',
          'Escolher quais indicadores e seções '
              'exibir primeiro no Dashboard '
              'de acordo com suas necessidades.',
        ),
      ),
    ];
  }

  // =====================================================
  // BENEFICIOS PREVISTOS PARA PREMIUM
  // =====================================================

  // Incluye Gratis y las propuestas de Pro,
  // más estas funciones avanzadas.

  List<_BeneficioPlan> _beneficiosPremium() {
    return [
      _BeneficioPlan(
        titulo: _t(
          'Estadísticas académicas avanzadas',
          'Estatísticas acadêmicas avançadas',
        ),
        descripcion: _t(
          'Analizar el rendimiento mediante '
              'gráficos, tendencias y comparaciones '
              'entre semanas o períodos de estudio.',
          'Analisar o desempenho por meio '
              'de gráficos, tendências e comparações '
              'entre semanas ou períodos de estudo.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Alertas inteligentes', 'Alertas inteligentes'),
        descripcion: _t(
          'Detectar posibles conflictos de horarios, '
              'entregas demasiado próximas '
              'o acumulación de actividades.',
          'Identificar possíveis conflitos '
              'de horários, prazos muito próximos '
              'ou acúmulo de atividades.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Recomendaciones de estudio', 'Recomendações de estudo'),
        descripcion: _t(
          'Recibir sugerencias sobre qué '
              'actividades priorizar considerando '
              'las fechas, el tiempo disponible '
              'y las tareas pendientes.',
          'Receber sugestões sobre quais '
              'atividades priorizar considerando '
              'os prazos, o tempo disponível '
              'e as tarefas pendentes.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Informes de rendimiento', 'Relatórios de desempenho'),
        descripcion: _t(
          'Generar informes resumidos del '
              'progreso académico para consultar '
              'o compartir fuera de la aplicación.',
          'Gerar relatórios resumidos do '
              'progresso acadêmico para consultar '
              'ou compartilhar fora do aplicativo.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Planificación académica inteligente',
          'Planejamento acadêmico inteligente',
        ),
        descripcion: _t(
          'Recibir ayuda para distribuir '
              'sesiones de estudio y preparación '
              'de exámenes según la carga académica.',
          'Receber ajuda para distribuir '
              'sessões de estudo e preparação '
              'para provas conforme a carga acadêmica.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t(
          'Análisis de hábitos de estudio',
          'Análise de hábitos de estudo',
        ),
        descripcion: _t(
          'Reconocer patrones de productividad '
              'y comparar períodos para identificar '
              'oportunidades de mejora.',
          'Reconhecer padrões de produtividade '
              'e comparar períodos para identificar '
              'oportunidades de melhoria.',
        ),
      ),

      _BeneficioPlan(
        titulo: _t('Nuevas herramientas Premium', 'Novas ferramentas Premium'),
        descripcion: _t(
          'Incorporar funciones exclusivas '
              'adicionales a medida que avance '
              'el desarrollo del proyecto.',
          'Incorporar novos recursos exclusivos '
              'conforme o desenvolvimento '
              'do projeto avançar.',
        ),
      ),
    ];
  }

  // =====================================================
  // OBTENER BENEFICIOS SEGÚN EL PLAN
  // =====================================================

  List<_BeneficioPlan> beneficiosPlan(String plan) {
    switch (plan) {
      case 'pro':
        return _beneficiosPro();

      case 'premium':
        return _beneficiosPremium();

      default:
        return _beneficiosGratis();
    }
  }

  // =====================================================
  // ETIQUETAS DE LAS TARJETAS
  // =====================================================

  Widget _etiqueta({required String texto, required bool esPlanActual}) {
    final oscuro = _esOscuro(context);

    final colorTexto = esPlanActual
        ? (oscuro ? const Color(0xFF81C784) : const Color(0xFF28633B))
        : _colorAcento(context);

    final colorFondo = esPlanActual
        ? (oscuro
              ? Colors.green.withValues(alpha: 0.16)
              : const Color(0xFFE6F4EA))
        : _fondoIcono(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        texto,

        style: TextStyle(
          color: colorTexto,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  // =====================================================
  // FILA DE BENEFICIO CON EXPLICACIÓN
  // =====================================================

  Widget _filaBeneficio(_BeneficioPlan beneficio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: _colorAcento(context),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  beneficio.titulo,

                  style: TextStyle(
                    color: _textoPrincipal(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  beneficio.descripcion,

                  style: TextStyle(
                    color: _textoSecundario(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // INFORMACIÓN DE BENEFICIOS HEREDADOS
  // =====================================================

  Widget _beneficiosIncluidos(String idPlan) {
    if (idPlan == 'gratis') {
      return const SizedBox.shrink();
    }

    final titulo = idPlan == 'pro'
        ? _t('Incluye todo el plan Gratis', 'Inclui todo o plano Grátis')
        : _t('Incluye Gratis y Pro', 'Inclui Grátis e Pro');

    final descripcion = idPlan == 'pro'
        ? _t(
            'Conservás todas las funciones esenciales '
                'de StudyTrack.',
            'Você mantém todas as funções essenciais '
                'do StudyTrack.',
          )
        : _t(
            'Conservás las funciones actuales '
                'y los beneficios previstos para Pro.',
            'Você mantém as funções atuais '
                'e os benefícios previstos para o Pro.',
          );

    return _filaBeneficio(
      _BeneficioPlan(titulo: titulo, descripcion: descripcion),
    );
  }

  // =====================================================
  // AVISO SOBRE BENEFICIOS EN DESARROLLO
  // =====================================================

  Widget _avisoDesarrollo() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: _fondoIcono(context),
        borderRadius: BorderRadius.circular(10),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.info_outline, color: _colorAcento(context), size: 20),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              _t(
                'Los beneficios adicionales de este '
                    'plan están previstos para futuras '
                    'versiones. Seleccionarlo ahora '
                    'no desbloquea nuevas funciones.',
                'Os benefícios adicionais deste '
                    'plano estão previstos para '
                    'versões futuras. Selecioná-lo '
                    'agora não libera novos recursos.',
              ),

              style: TextStyle(
                color: _textoPrincipal(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TARJETAS DE LOS PLANES
  // =====================================================

  Widget buildPlanCard({required String idPlan, required bool destacado}) {
    final seleccionado = planSeleccionado == idPlan;

    final actual = planActual == idPlan;

    final esGratis = idPlan == 'gratis';

    final esOscuro = _esOscuro(context);

    final acento = _colorAcento(context);

    final textoPrincipal = _textoPrincipal(context);

    final textoSecundario = _textoSecundario(context);

    final beneficios = beneficiosPlan(idPlan);

    return GestureDetector(
      onTap: () {
        setState(() {
          planSeleccionado = idPlan;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: _fondoTarjeta(context),

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: seleccionado ? acento : _bordeTarjeta(context),

            width: seleccionado ? 2 : 1,
          ),

          boxShadow: esOscuro
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ========================================
            // ETIQUETAS
            // ========================================

            if (actual || idPlan == 'pro')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),

                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,

                  children: [
                    if (actual)
                      _etiqueta(
                        texto: _t('PLAN ACTUAL', 'PLANO ATUAL'),
                        esPlanActual: true,
                      ),

                    if (idPlan == 'pro')
                      _etiqueta(
                        texto: _t('RECOMENDADO', 'RECOMENDADO'),
                        esPlanActual: false,
                      ),
                  ],
                ),
              ),

            // ========================================
            // NOMBRE DEL PLAN Y SELECCIÓN
            // ========================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Expanded(
                  child: Text(
                    nombrePlan(idPlan),

                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textoPrincipal,
                    ),
                  ),
                ),

                Radio<String>(value: idPlan, activeColor: acento),
              ],
            ),

            // ========================================
            // SUBTÍTULO
            // ========================================
            Text(
              _subtituloPlan(idPlan),

              style: TextStyle(
                color: textoSecundario,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // ========================================
            // DESCRIPCIÓN GENERAL
            // ========================================
            Text(
              _descripcionPlan(idPlan),

              style: TextStyle(
                color: textoPrincipal,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            // ========================================
            // PRECIO MENSUAL
            // ========================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(
                  precioPlan(idPlan),

                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,

                    color: destacado ? acento : textoPrincipal,
                  ),
                ),

                const SizedBox(width: 6),

                Padding(
                  padding: const EdgeInsets.only(bottom: 5),

                  child: Text(
                    _t('/ mes', '/ mês'),

                    style: TextStyle(color: textoSecundario, fontSize: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Divider(color: _bordeTarjeta(context)),

            const SizedBox(height: 12),

            // ========================================
            // PERFIL DEL ESTUDIANTE
            // ========================================
            Text(
              _t('IDEAL PARA', 'IDEAL PARA'),

              style: TextStyle(
                color: acento,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _idealPara(idPlan),

              style: TextStyle(
                color: textoSecundario,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            // ========================================
            // TÍTULO DE BENEFICIOS
            // ========================================
            Text(
              esGratis
                  ? _t('FUNCIONES DISPONIBLES', 'RECURSOS DISPONÍVEIS')
                  : _t('BENEFICIOS PREVISTOS', 'BENEFÍCIOS PREVISTOS'),

              style: TextStyle(
                color: acento,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 14),

            // ========================================
            // BENEFICIOS DE PLANES ANTERIORES
            // ========================================
            if (!esGratis) _beneficiosIncluidos(idPlan),

            // ========================================
            // BENEFICIOS DETALLADOS
            // ========================================
            ...beneficios.map((beneficio) => _filaBeneficio(beneficio)),

            // ========================================
            // AVISO DE FUNCIONES FUTURAS
            // ========================================
            if (!esGratis) ...[const SizedBox(height: 2), _avisoDesarrollo()],
          ],
        ),
      ),
    );
  }

  // =====================================================
  // MÉTODOS DE PAGO SIMULADOS
  // =====================================================

  Widget buildMetodoPago() {
    if (planSeleccionado == 'gratis') {
      return const SizedBox.shrink();
    }

    final acento = _colorAcento(context);

    final textoPrincipal = _textoPrincipal(context);

    final textoSecundario = _textoSecundario(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: _fondoTarjeta(context),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: _bordeTarjeta(context)),
      ),

      // Se mantienen los mismos identificadores:
      // tarjeta, transferencia y pix.
      child: RadioGroup<String>(
        groupValue: metodoPago,

        onChanged: (String? valor) {
          if (valor == null) return;

          setState(() {
            metodoPago = valor;
          });
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ========================================
            // TÍTULO
            // ========================================

            Text(
              _t('Método de pago (simulado)', 'Forma de pagamento (simulada)'),

              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textoPrincipal,
              ),
            ),

            const SizedBox(height: 8),

            // ========================================
            // TARJETA
            // ========================================
            RadioListTile<String>(
              value: 'tarjeta',
              activeColor: acento,
              contentPadding: EdgeInsets.zero,

              title: Text(
                _t(
                  'Tarjeta de crédito o débito',
                  'Cartão de crédito ou débito',
                ),

                style: TextStyle(color: textoPrincipal),
              ),
            ),

            // ========================================
            // TRANSFERENCIA
            // ========================================
            RadioListTile<String>(
              value: 'transferencia',
              activeColor: acento,
              contentPadding: EdgeInsets.zero,

              title: Text(
                _t('Transferencia bancaria', 'Transferência bancária'),

                style: TextStyle(color: textoPrincipal),
              ),
            ),

            // ========================================
            // PIX
            // ========================================
            RadioListTile<String>(
              value: 'pix',
              activeColor: acento,
              contentPadding: EdgeInsets.zero,

              title: Text('PIX', style: TextStyle(color: textoPrincipal)),
            ),

            const SizedBox(height: 8),

            // ========================================
            // AVISO SOBRE PAGOS
            // ========================================
            Text(
              _t(
                'Los pagos son simulados. No se '
                    'solicita información bancaria real '
                    'ni se realiza ningún cobro.',
                'Os pagamentos são simulados. '
                    'Não são solicitados dados bancários '
                    'reais e nenhuma cobrança é realizada.',
              ),

              style: TextStyle(
                color: textoSecundario,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // AVISO FINAL DE DEMOSTRACIÓN ACADÉMICA
  // =====================================================

  Widget _avisoDemostracion() {
    return Center(
      child: Text(
        _t(
          'Demostración académica de StudyTrack. '
              'No se realizan cobros reales. '
              'Los planes Pro y Premium representan '
              'propuestas de futuras funcionalidades '
              'y actualmente no desbloquean '
              'herramientas exclusivas.',
          'Demonstração acadêmica do StudyTrack. '
              'Nenhuma cobrança real é realizada. '
              'Os planos Pro e Premium representam '
              'propostas de funcionalidades futuras '
              'e atualmente não liberam '
              'ferramentas exclusivas.',
        ),

        textAlign: TextAlign.center,

        style: TextStyle(
          color: _textoSecundario(context),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  // =====================================================
  // PANTALLA PRINCIPAL
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final acento = _colorAcento(context);

    final textoSecundario = _textoSecundario(context);

    return Scaffold(
      // Fondo adaptativo.
      backgroundColor: tema.scaffoldBackgroundColor,

      // ========================================
      // APPBAR INSTITUCIONAL
      // ========================================
      appBar: AppBar(
        backgroundColor: bordo,
        foregroundColor: Colors.white,

        title: Text(_t('Planes de StudyTrack', 'Planos do StudyTrack')),
      ),

      // ========================================
      // CONTENIDO
      // ========================================
      body: cargando
          ? Center(child: CircularProgressIndicator(color: acento))
          : errorCarga
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Text(
                  _t(
                    'No se pudo verificar tu plan. '
                        'Revisá tu sesión y la conexión '
                        'con StudyTrack.',
                    'Não foi possível verificar '
                        'seu plano. Confira sua sessão '
                        'e a conexão com o StudyTrack.',
                  ),

                  textAlign: TextAlign.center,

                  style: tema.textTheme.bodyLarge,
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),

                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        // ============================
                        // INTRODUCCIÓN
                        // ============================

                        Text(
                          _t(
                            'Elegí el plan que mejor '
                                'se adapte a vos.',
                            'Escolha o plano que melhor '
                                'combina com você.',
                          ),

                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _t(
                            'Compará las funciones '
                                'disponibles y descubrí '
                                'qué herramientas están '
                                'previstas para cada plan.',
                            'Compare os recursos '
                                'disponíveis e descubra '
                                'quais ferramentas estão '
                                'previstas para cada plano.',
                          ),

                          style: TextStyle(
                            fontSize: 14,
                            color: textoSecundario,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ============================
                        // SELECCIÓN DE PLANES
                        // ============================
                        RadioGroup<String>(
                          groupValue: planSeleccionado,

                          onChanged: (String? valor) {
                            if (valor == null) return;

                            setState(() {
                              planSeleccionado = valor;
                            });
                          },

                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // ====================
                              // PANTALLAS ANCHAS
                              // ====================

                              if (constraints.maxWidth >= 850) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Expanded(
                                      child: buildPlanCard(
                                        idPlan: 'gratis',
                                        destacado: false,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: buildPlanCard(
                                        idPlan: 'pro',
                                        destacado: true,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: buildPlanCard(
                                        idPlan: 'premium',
                                        destacado: true,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              // ====================
                              // CELULARES
                              // ====================

                              return Column(
                                children: [
                                  buildPlanCard(
                                    idPlan: 'gratis',
                                    destacado: false,
                                  ),

                                  buildPlanCard(idPlan: 'pro', destacado: true),

                                  buildPlanCard(
                                    idPlan: 'premium',
                                    destacado: true,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // ============================
                        // MÉTODOS DE PAGO
                        // ============================
                        buildMetodoPago(),

                        const SizedBox(height: 20),

                        // ============================
                        // BOTÓN APLICAR PLAN
                        // ============================
                        SizedBox(
                          width: double.infinity,
                          height: 54,

                          child: ElevatedButton.icon(
                            onPressed: guardando ? null : aplicarPlan,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: acento,

                              foregroundColor: _textoSobreAcento(context),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),

                            icon: guardando
                                ? SizedBox(
                                    width: 18,
                                    height: 18,

                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,

                                      color: _textoSobreAcento(context),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),

                            label: Text(
                              guardando
                                  ? _t('Aplicando...', 'Aplicando...')
                                  : _t('Aplicar plan', 'Aplicar plano'),

                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ============================
                        // ACLARACIÓN ACADÉMICA
                        // ============================
                        _avisoDemostracion(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

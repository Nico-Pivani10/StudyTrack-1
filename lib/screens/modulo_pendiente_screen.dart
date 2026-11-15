import 'package:flutter/material.dart';

class ModuloPendienteScreen extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String responsable;
  final IconData icono;

  static const Color bordo = Color(0xFF670810);

  const ModuloPendienteScreen({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.responsable,
    required this.icono,
  });

  // Módulo de Tareas desarrollado por Nicolás.
  const ModuloPendienteScreen.tareas({super.key})
    : titulo = 'Gestión de tareas',
      descripcion =
          'Este módulo fue desarrollado y está pendiente '
          'de integración con StudyTrack.',
      responsable = 'Nicolás Pivani',
      icono = Icons.task_alt;

  // Módulo GPS desarrollado por Nicolás.
  const ModuloPendienteScreen.gps({super.key})
    : titulo = 'GPS y geolocalización',
      descripcion =
          'El módulo de ubicación y mapas ya fue desarrollado '
          'y está pendiente de integración con StudyTrack.',
      responsable = 'Nicolás Pivani',
      icono = Icons.map_outlined;

  // Módulo de notificaciones.
  const ModuloPendienteScreen.notificaciones({super.key})
    : titulo = 'Notificaciones',
      descripcion =
          'La integración de notificaciones y recordatorios '
          'se encuentra pendiente.',
      responsable = 'Nicolás Pivani',
      icono = Icons.notifications_outlined;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'StudyTrack',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: bordo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícono de la funcionalidad.
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4E9EB),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono, color: bordo, size: 52),
                      ),

                      const SizedBox(height: 24),

                      // Nombre del módulo.
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Estado de integración.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4E9EB),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.integration_instructions_outlined,
                              color: bordo,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Pendiente de integración',
                                style: TextStyle(
                                  color: bordo,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Explicación.
                      Text(
                        descripcion,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyLarge,
                      ),

                      const SizedBox(height: 24),

                      Divider(color: colores.outlineVariant),

                      const SizedBox(height: 16),

                      // Responsable.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: bordo,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Responsable: $responsable',
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Volver al Dashboard.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Volver al inicio'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bordo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

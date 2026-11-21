
import 'package:flutter/material.dart';
import '../services/notification_history.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color bordo = Color(0xFF670310);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: bordo,
        foregroundColor: Colors.white,
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            icon: const Icon(Icons.done_all),
            onPressed: NotificationHistory.marcarTodasLeidas,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: NotificationHistory.notificaciones,
        builder: (context, lista, _) {
          if (lista.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 70,
                    color: bordo,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay notificaciones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Tus avisos aparecerán aquí.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final aviso = lista[index];
              final leida = aviso['leida'] == true;

              return Card(
                color: leida
                    ? Colors.white
                    : const Color(0xFFFFF0F1),
                child: ListTile(
                  leading: Icon(
                    aviso['tipo'] == 'gps'
                        ? Icons.location_on
                        : Icons.notifications_active,
                    color: bordo,
                  ),
                  title: Text(
                    aviso['titulo'].toString(),
                    style: TextStyle(
                      fontWeight: leida
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(aviso['mensaje'].toString()),
                  trailing: leida
                      ? const Icon(
                          Icons.check,
                          color: Colors.grey,
                        )
                      : const Icon(
                          Icons.circle,
                          size: 10,
                          color: bordo,
                        ),
                  onTap: () {
                    NotificationHistory.marcarLeida(
                      aviso['id'] as int,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}//Niklaus

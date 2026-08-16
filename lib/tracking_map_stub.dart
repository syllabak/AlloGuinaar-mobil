import 'package:flutter/material.dart';

/// Stub web/desktop — aucune dépendance WebView
class TrackingMapWidget extends StatelessWidget {
  final Map<String, dynamic>? tracking;
  const TrackingMapWidget({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("Carte disponible sur Android uniquement",
        style: TextStyle(color: Colors.grey)));
  }
}
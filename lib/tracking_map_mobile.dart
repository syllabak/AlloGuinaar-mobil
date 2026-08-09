import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Widget carte Leaflet — Android / iOS uniquement
class TrackingMapWidget extends StatefulWidget {
  final Map<String, dynamic>? tracking;
  const TrackingMapWidget({super.key, required this.tracking});
  @override State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> {
  late WebViewController _ctrl;
  bool _mapReady = false;
  Map<String, dynamic>? _lastTracking;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _mapReady = true;
          if (widget.tracking != null) _mettreAJour(widget.tracking!);
        },
      ))
      ..loadHtmlString(_buildHtml());
  }

  @override
  void didUpdateWidget(TrackingMapWidget old) {
    super.didUpdateWidget(old);
    // Mettre à jour la carte quand les données changent
    if (widget.tracking != null &&
        widget.tracking != _lastTracking &&
        _mapReady) {
      _mettreAJour(widget.tracking!);
    }
  }

  void _mettreAJour(Map<String, dynamic> d) {
    final lLat = d['livreur_lat'];
    final lLng = d['livreur_lng'];
    if (lLat == null || lLng == null) return;
    _lastTracking = d;

    final cLat = d['dest_lat'];
    final cLng = d['dest_lng'];
    final fLat = d['ferme_lat'];
    final fLng = d['ferme_lng'];

    final js = """
      if(window.livreurMarker) {
        window.livreurMarker.setLatLng([$lLat,$lLng]);
      } else {
        window.livreurMarker = L.marker([$lLat,$lLng],{icon:livreurIcon})
          .addTo(map).bindPopup('🚚 Livreur');
      }
      if(!window.mapInit){
        window.mapInit = true;
        ${cLat != null ? "L.marker([$cLat,$cLng],{icon:clientIcon}).addTo(map).bindPopup('📍 Vous');" : ""}
        ${fLat != null ? "L.marker([$fLat,$fLng],{icon:fermeIcon}).addTo(map).bindPopup('🏪 Ferme');" : ""}
        map.setView([$lLat,$lLng], 14);
      } else {
        map.panTo([$lLat,$lLng]);
      }
    """;
    _ctrl.runJavaScript(js);
  }

  String _buildHtml() {
    return """<!DOCTYPE html><html><head>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<link rel='stylesheet' href='https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'/>
<script src='https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'></script>
<style>html,body,#map{margin:0;padding:0;width:100%;height:100%}</style>
</head><body><div id='map'></div><script>
var map = L.map('map').setView([14.6928,-17.4467], 13);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:18}).addTo(map);
function mkIcon(e,bg){
  return L.divIcon({className:'',iconSize:[36,36],iconAnchor:[18,36],
    html:"<div style='background:"+bg+";color:white;width:36px;height:36px;border-radius:50%;"
      +"display:flex;align-items:center;justify-content:center;font-size:18px;"
      +"border:2px solid white;box-shadow:0 2px 8px rgba(0,0,0,.3)'>"+e+"</div>"});
}
var livreurIcon=mkIcon('🚚','#2563eb');
var clientIcon =mkIcon('📍','#8b0000');
var fermeIcon  =mkIcon('🏪','#16a34a');
window.livreurMarker = null;
window.mapInit = false;
</script></body></html>""";
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _ctrl);
}
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:app/widgets/patha_header.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────

enum RoadRisk { safe, warning, highRisk }

class _ReportPoint {
  final String id;
  final double lat;
  final double lng;
  final String type;
  final String severity;
  final String location;
  final String status;
  final String timestamp;
  final List<String> images;

  const _ReportPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.severity,
    required this.location,
    required this.status,
    required this.timestamp,
    required this.images,
  });
}

class _Cluster {
  final List<_ReportPoint> points;
  final double lat;
  final double lng;

  _Cluster({required this.points, required this.lat, required this.lng});

  RoadRisk get risk {
    final severe   = points.where((p) => p.severity.toLowerCase() == "severe").length;
    final moderate = points.where((p) => p.severity.toLowerCase() == "moderate").length;
    if (severe > 0 || points.length >= 3) return RoadRisk.highRisk;
    if (moderate > 0 || points.length >= 2) return RoadRisk.warning;
    return RoadRisk.safe;
  }

  Color get color {
    switch (risk) {
      case RoadRisk.highRisk: return const Color(0xFFFF4D4D);
      case RoadRisk.warning:  return const Color(0xFFFFB547);
      case RoadRisk.safe:     return const Color(0xFF2DD4A0);
    }
  }

  String get riskLabel {
    switch (risk) {
      case RoadRisk.highRisk: return "High Risk";
      case RoadRisk.warning:  return "Warning";
      case RoadRisk.safe:     return "Safe";
    }
  }

  String get dominantType {
    final freq = <String, int>{};
    for (final p in points) freq[p.type] = (freq[p.type] ?? 0) + 1;
    return freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

double _distKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

List<_Cluster> _clusterPoints(List<_ReportPoint> points) {
  final used     = List.filled(points.length, false);
  final clusters = <_Cluster>[];
  for (int i = 0; i < points.length; i++) {
    if (used[i]) continue;
    final group = [points[i]];
    used[i] = true;
    for (int j = i + 1; j < points.length; j++) {
      if (!used[j] &&
          _distKm(points[i].lat, points[i].lng,
                  points[j].lat, points[j].lng) < 0.35) {
        group.add(points[j]);
        used[j] = true;
      }
    }
    final cLat = group.map((p) => p.lat).reduce((a, b) => a + b) / group.length;
    final cLng = group.map((p) => p.lng).reduce((a, b) => a + b) / group.length;
    clusters.add(_Cluster(points: group, lat: cLat, lng: cLng));
  }
  return clusters;
}

String _timeAgo(String? tsMs) {
  if (tsMs == null || tsMs.isEmpty) return "";
  final ts = int.tryParse(tsMs);
  if (ts == null) return "";
  final diff = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (diff.inDays > 0)    return "${diff.inDays}d ago";
  if (diff.inHours > 0)   return "${diff.inHours}h ago";
  if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
  return "Just now";
}

// ─────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();

  final _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://patha-2305-default-rtdb.asia-southeast1.firebasedatabase.app/",
  ).ref("reports");

  List<_ReportPoint> _allPoints = [];
  List<_Cluster>     _clusters  = [];
  String             _filter    = "All";
  _Cluster?          _selected; // currently tapped cluster

  // Solapur city center
  static const _solapur = LatLng(17.6868, 75.9064);

  @override
  void initState() {
    super.initState();
    _listenToReports();
  }

  // ─────────────────────────────────────────
  // FIREBASE LIVE LISTENER
  // ─────────────────────────────────────────
  void _listenToReports() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        if (mounted) setState(() { _allPoints = []; _clusters = []; });
        return;
      }

      final map    = Map<dynamic, dynamic>.from(data);
      final points = <_ReportPoint>[];

      for (final entry in map.entries) {
        try {
          final v   = Map<String, dynamic>.from(entry.value as Map);
          final lat = (v["latitude"]  as num?)?.toDouble();
          final lng = (v["longitude"] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          // Handle both List and Map image formats from Firebase
          List<String> imgs = [];
          final rawImgs = v["images"];
          if (rawImgs is List) {
            imgs = rawImgs
                .where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString()).toList();
          } else if (rawImgs is Map) {
            imgs = rawImgs.values
                .where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString()).toList();
          }

          points.add(_ReportPoint(
            id:        entry.key.toString(),
            lat:       lat,
            lng:       lng,
            type:      v["type"]?.toString()      ?? "Unknown",
            severity:  v["severity"]?.toString()  ?? "Minor",
            location:  v["location"]?.toString()  ?? "—",
            status:    v["status"]?.toString()    ?? "Reported",
            timestamp: v["timestamp"]?.toString() ?? "",
            images:    imgs,
          ));
        } catch (_) {}
      }

      if (mounted) {
        _allPoints = points;
        _rebuildClusters();
      }
    });
  }

  void _rebuildClusters() {
    List<_ReportPoint> filtered = _allPoints;
    if (_filter == "High Risk") {
      filtered = _allPoints.where((p) => p.severity.toLowerCase() == "severe").toList();
    } else if (_filter == "Warning") {
      filtered = _allPoints.where((p) => p.severity.toLowerCase() == "moderate").toList();
    } else if (_filter == "Safe") {
      filtered = _allPoints.where((p) => p.severity.toLowerCase() == "minor").toList();
    }
    setState(() {
      _clusters = _clusterPoints(filtered);
      _selected = null;
    });
  }

  // ─────────────────────────────────────────
  // GO TO MY LOCATION
  // ─────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {}
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // ── HEADER ────────────────────────────
          PathaHeader(
            activeRoute: '/map',
            navItems: const [
              {'label': 'Home',       'route': '/home'},
              {'label': 'Report',     'route': '/reports'},
              {'label': 'Complaints', 'route': '/complaints'},
              {'label': 'Track',      'route': '/TrackComplaints'},
            ],
          ),

          // ── FILTER BAR ────────────────────────
          _FilterBar(
            selected: _filter,
            onSelect: (f) { setState(() => _filter = f); _rebuildClusters(); },
            counts: {
              "All":       _allPoints.length,
              "High Risk": _allPoints.where((p) =>
                  p.severity.toLowerCase() == "severe").length,
              "Warning":   _allPoints.where((p) =>
                  p.severity.toLowerCase() == "moderate").length,
              "Safe":      _allPoints.where((p) =>
                  p.severity.toLowerCase() == "minor").length,
            },
          ),

          // ── MAP + OVERLAYS ────────────────────
          Expanded(
            child: Stack(
              children: [

                // ── FLUTTER MAP ─────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _solapur,
                    initialZoom: 13,
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    // OpenStreetMap tile layer — FREE
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.patha.app',
                    ),

                    // Cluster markers layer
                    MarkerLayer(
                      markers: _clusters.map((c) {
                        final isSelected = _selected == c;
                        return Marker(
                          point: LatLng(c.lat, c.lng),
                          width: isSelected ? 56 : 48,
                          height: isSelected ? 56 : 48,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selected = c);
                              _showClusterSheet(c);
                            },
                            child: _ClusterMarker(
                              cluster: c,
                              isSelected: isSelected,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // ── STATS CARD (top right) ───────
                Positioned(
                  top: 12, right: 12,
                  child: _StatsCard(
                    total:    _allPoints.length,
                    highRisk: _allPoints.where((p) =>
                        p.severity.toLowerCase() == "severe").length,
                    clusters: _clusters.length,
                  ),
                ),

                // ── LEGEND (bottom left) ─────────
                Positioned(
                  bottom: 110, left: 12,
                  child: _Legend(),
                ),

                // ── ZOOM + LOCATION BUTTONS ──────
                Positioned(
                  bottom: 24, right: 12,
                  child: Column(
                    children: [
                      _MapBtn(
                        icon: Icons.my_location_rounded,
                        onTap: _goToMyLocation,
                      ),
                      const SizedBox(height: 8),
                      _MapBtn(
                        icon: Icons.add_rounded,
                        onTap: () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1),
                      ),
                      const SizedBox(height: 8),
                      _MapBtn(
                        icon: Icons.remove_rounded,
                        onTap: () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1),
                      ),
                    ],
                  ),
                ),

                // ── EMPTY STATE ──────────────────
                if (_allPoints.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        "No reports on map yet",
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClusterSheet(_Cluster c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ClusterSheet(cluster: c),
    );
  }
}

// ─────────────────────────────────────────────
// CLUSTER MARKER WIDGET
// ─────────────────────────────────────────────

class _ClusterMarker extends StatelessWidget {
  final _Cluster cluster;
  final bool isSelected;

  const _ClusterMarker({required this.cluster, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final c = cluster;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width:  isSelected ? 56 : 48,
      height: isSelected ? 56 : 48,
      decoration: BoxDecoration(
        color: c.color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: c.color,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: c.color.withOpacity(isSelected ? 0.5 : 0.3),
            blurRadius: isSelected ? 16 : 10,
            spreadRadius: isSelected ? 3 : 1,
          ),
        ],
      ),
      child: Center(
        child: c.points.length > 1
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${c.points.length}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: c.color,
                    ),
                  ),
                  Text(
                    "reports",
                    style: GoogleFonts.poppins(
                      fontSize: 7,
                      color: c.color.withOpacity(0.8),
                    ),
                  ),
                ],
              )
            : Icon(
                _iconForType(c.dominantType),
                color: c.color,
                size: 20,
              ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case "pothole":      return Icons.circle_outlined;
      case "crack":        return Icons.linear_scale_rounded;
      case "waterlogging": return Icons.water_rounded;
      default:             return Icons.warning_amber_rounded;
    }
  }
}

// ─────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final Map<String, int> counts;

  const _FilterBar({
    required this.selected,
    required this.onSelect,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final items = {
      "All":       const Color(0xFFFF6B2B),
      "High Risk": const Color(0xFFFF4D4D),
      "Warning":   const Color(0xFFFFB547),
      "Safe":      const Color(0xFF2DD4A0),
    };

    return Container(
      height: 48,
      color: const Color(0xFF0D1B2A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: items.entries.map((entry) {
          final isActive = selected == entry.key;
          final color    = entry.value;
          final count    = counts[entry.key] ?? 0;

          return GestureDetector(
            onTap: () => onSelect(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.18)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.7)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Text(entry.key,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive
                            ? color
                            : Colors.white.withOpacity(0.5),
                      )),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("$count",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          )),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATS CARD
// ─────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int total;
  final int highRisk;
  final int clusters;

  const _StatsCard({
    required this.total,
    required this.highRisk,
    required this.clusters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.93),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("LIVE OVERVIEW",
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 8),
          _row("Total Reports",  "$total",    Colors.white.withOpacity(0.7)),
          _row("High Risk Zones","$highRisk", const Color(0xFFFF4D4D)),
          _row("Road Clusters",  "$clusters", const Color(0xFFFF6B2B)),
        ],
      ),
    );
  }

  Widget _row(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4))),
          const SizedBox(width: 20),
          Text(val,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LEGEND
// ─────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.93),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ROAD CONDITION",
              style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 8),
          _item(const Color(0xFFFF4D4D), "High Risk  (Severe)"),
          _item(const Color(0xFFFFB547), "Warning  (Moderate)"),
          _item(const Color(0xFF2DD4A0), "Safe  (Minor)"),
        ],
      ),
    );
  }

  Widget _item(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAP BUTTON
// ─────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLUSTER BOTTOM SHEET
// ─────────────────────────────────────────────

class _ClusterSheet extends StatelessWidget {
  final _Cluster cluster;

  const _ClusterSheet({required this.cluster});

  @override
  Widget build(BuildContext context) {
    final c         = cluster;
    final reports   = c.points;
    final allImages = reports.expand((p) => p.images).toList();
    final latest    = reports.isNotEmpty ? reports.last : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Risk badge + report count
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.color.withOpacity(0.5)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: c.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(c.riskLabel,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.color)),
                        ]),
                      ),
                      const Spacer(),
                      Text(
                        "${reports.length} report${reports.length > 1 ? 's' : ''}",
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(c.dominantType,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),

                  if (latest != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_rounded,
                          size: 13, color: const Color(0xFFFF6B2B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(latest.location,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.45)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(_timeAgo(latest.timestamp),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.3))),
                    ]),
                  ],

                  const SizedBox(height: 16),

                  // Stats row
                  Row(children: [
                    _stat("Reports",     "${reports.length}",
                        const Color(0xFFFF6B2B)),
                    _stat("Severe",
                        "${reports.where((p) => p.severity.toLowerCase() == 'severe').length}",
                        const Color(0xFFFF4D4D)),
                    _stat("In Progress",
                        "${reports.where((p) => p.status.toLowerCase() == 'in progress').length}",
                        const Color(0xFF4A90E2)),
                    _stat("Resolved",
                        "${reports.where((p) => p.status.toLowerCase() == 'completed').length}",
                        const Color(0xFF2DD4A0)),
                  ]),

                  // Images
                  if (allImages.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text("Photos",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.38),
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allImages.length,
                        itemBuilder: (_, i) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              allImages[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Individual reports list
                  Text("Reports in this area",
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.38),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),

                  ...reports.map((p) {
                    final sevColor = p.severity.toLowerCase() == "severe"
                        ? const Color(0xFFFF4D4D)
                        : p.severity.toLowerCase() == "moderate"
                            ? const Color(0xFFFFB547)
                            : const Color(0xFF2DD4A0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: sevColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.type,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                        Text(p.severity,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.4))),
                        const SizedBox(width: 8),
                        Text(_timeAgo(p.timestamp),
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.3))),
                      ]),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String val, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(val,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.35))),
        ]),
      ),
    );
  }
}
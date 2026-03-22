import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/widgets/patha_header.dart';

class MyComplaints extends StatefulWidget {
  const MyComplaints({super.key});

  @override
  State<MyComplaints> createState() => _MyComplaintsState();
}

class _MyComplaintsState extends State<MyComplaints> {
  final dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://patha-2305-default-rtdb.asia-southeast1.firebasedatabase.app/",
  ).ref("reports");

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    const rightPanelW = 260.0;
    // Show side panel only on wide screens (tablet/web)
    // On mobile: show helpline as floating button → bottom sheet
    final showSidePanel = screenW > 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      // ✅ Mobile: floating helpline button bottom-right
      floatingActionButton: !showSidePanel
          ? FloatingActionButton.small(
              backgroundColor: const Color(0xFFFF6B2B),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24)),
                    ),
                    child: const SingleChildScrollView(
                      child: _RightPanel(),
                    ),
                  ),
                );
              },
              child: const Icon(Icons.contact_phone_rounded,
                  color: Colors.white, size: 20),
            )
          : null,
      body: Column(
        children: [
          PathaHeader(
            activeRoute: '/complaints',
            navItems: const [
              {'label': 'Home',   'route': '/home'},
              {'label': 'Report', 'route': '/reports'},
              {'label': 'Track',  'route': '/TrackComplaints'},
              {'label': 'Map',    'route': '/map'},
            ],
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── LEFT: COMPLAINTS LIST ───────────────
                Expanded(
                  child: StreamBuilder(
                    stream: dbRef.onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFFF6B2B)));
                      }

                      final data = snapshot.data!.snapshot.value;
                      if (data == null) {
                        return Center(
                          child: Text("No complaints yet",
                              style: GoogleFonts.poppins(
                                  color: Colors.white54)),
                        );
                      }

                      final map =
                          Map<dynamic, dynamic>.from(data as Map);
                      final list =
                          map.entries.toList().reversed.toList();

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final raw = list[index].value;
                          if (raw == null || raw is! Map) {
                            return const SizedBox.shrink();
                          }
                          final item = Map<String, dynamic>.from(raw);

                          // ✅ Firebase returns images as Map{0:url} OR List
                          final rawImgs = item["images"];
                          List<String> imgUrls = [];
                          if (rawImgs is List) {
                            imgUrls = rawImgs
                                .where((e) => e != null && e.toString().isNotEmpty)
                                .map((e) => e.toString())
                                .toList();
                          } else if (rawImgs is Map) {
                            imgUrls = rawImgs.values
                                .where((e) => e != null && e.toString().isNotEmpty)
                                .map((e) => e.toString())
                                .toList();
                          }
                          final hasImage = imgUrls.isNotEmpty;

                          return _TappableCard(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/TrackComplaints',
                              arguments: {
                                "id": list[index].key,
                                "data": item,
                              },
                            ),
                            child: _ComplaintCard(
                              item: item,
                              hasImage: hasImage,
                              imageUrl: hasImage ? imgUrls[0] : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // ── RIGHT PANEL ─────────────────────────
                if (showSidePanel)
                  SizedBox(
                    width: rightPanelW,
                    child: const _RightPanel(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPLAINT CARD
// ─────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool hasImage;
  final String? imageUrl;

  const _ComplaintCard({
    required this.item,
    required this.hasImage,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (hasImage && imageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type
                Text(
                  item["type"] ?? "Unknown",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: Color(0xFFFF6B2B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item["location"] ?? "",
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Chips row
                Row(
                  children: [
                    _chip(item["severity"] ?? "",
                        _severityColor(item["severity"] ?? "")),
                    const SizedBox(width: 8),
                    _chip(item["status"] ?? "Reported",
                        _statusColor(item["status"] ?? "")),
                    const Spacer(),
                    // Tap hint
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: Colors.white24),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case "severe":
        return const Color(0xFFFF4D4D);
      case "moderate":
        return const Color(0xFFFFB547);
      default:
        return const Color(0xFF2DD4A0);
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case "completed":
        return const Color(0xFF2DD4A0);
      case "in progress":
        return const Color(0xFFFF6B2B);
      case "assigned":
        return Colors.blueAccent;
      default:
        return Colors.white54;
    }
  }

  Widget _chip(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────
// RIGHT PANEL — User Profile + Helplines
// ─────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── USER PROFILE ──────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B2B), Color(0xFFFF8C5A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 2),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Citizen User",             // 🔁 Replace with auth user name
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Solapur, Maharashtra",
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white.withOpacity(0.4)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B2B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFFF6B2B).withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text("View Profile",
                          style: GoogleFonts.poppins(
                              color: const Color(0xFFFF6B2B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── SECTION LABEL ─────────────────
            _panelSectionLabel("Emergency Contacts"),

            const SizedBox(height: 12),

            // ── HELPLINE CARDS ────────────────
            _helplineCard(
              icon: Icons.local_police_rounded,
              color: const Color(0xFF4A90E2),
              title: "Solapur Police",
              value: "0217-2727272",
              isPhone: true,
            ),
            _helplineCard(
              icon: Icons.engineering_rounded,
              color: const Color(0xFF2DD4A0),
              title: "PWD Solapur",
              value: "0217-2300100",
              isPhone: true,
            ),
            _helplineCard(
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF4D4D),
              title: "Municipal Fire",
              value: "101",
              isPhone: true,
            ),
            _helplineCard(
              icon: Icons.health_and_safety_rounded,
              color: const Color(0xFFFFB547),
              title: "Road Ambulance",
              value: "108",
              isPhone: true,
            ),

            const SizedBox(height: 20),

            _panelSectionLabel("Email Support"),

            const SizedBox(height: 12),

            _helplineCard(
              icon: Icons.email_rounded,
              color: const Color(0xFFB47EFF),
              title: "PWD Complaints",
              value: "pwd.solapur@maharashtra.gov.in",
              isPhone: false,
            ),
            _helplineCard(
              icon: Icons.email_rounded,
              color: const Color(0xFF4A90E2),
              title: "Municipal Corp",
              value: "smc@solapurcity.gov.in",
              isPhone: false,
            ),

            const SizedBox(height: 20),

            // ── FOOTER NOTE ───────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4A0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2DD4A0).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF2DD4A0), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "For road emergencies, call PWD or dial 1800-22-0233 (NHAI toll free)",
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white38,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B2B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _helplineCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required bool isPhone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            isPhone
                ? Icons.phone_rounded
                : Icons.open_in_new_rounded,
            color: Colors.white.withOpacity(0.2),
            size: 15,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAPPABLE CARD — instant scale, no InkWell lag
// ─────────────────────────────────────────────

class _TappableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TappableCard({required this.child, required this.onTap});

  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); },
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale:    _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve:    Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
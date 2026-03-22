import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/widgets/patha_header.dart';

// ─────────────────────────────────────────────
// STAGE DEFINITIONS
// ─────────────────────────────────────────────

class _Stage {
  final String key;
  final String label;
  final IconData icon;
  const _Stage(this.key, this.label, this.icon);
}

const _stages = [
  _Stage("reported",    "Reported",    Icons.upload_file_rounded),
  _Stage("received",    "Received",    Icons.mark_email_read_rounded),
  _Stage("verified",    "Verified",    Icons.verified_rounded),
  _Stage("assigned",    "Assigned",    Icons.engineering_rounded),
  _Stage("in progress", "In Progress", Icons.construction_rounded),
  _Stage("completed",   "Completed",   Icons.check_circle_rounded),
];

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

int _stageIndex(String status) {
  final s = status.toLowerCase().trim();
  for (int i = 0; i < _stages.length; i++) {
    if (_stages[i].key == s) return i;
  }
  return 0; // default to "Reported"
}

Color _severityColor(String s) {
  switch (s.toLowerCase()) {
    case "severe":   return const Color(0xFFFF4D4D);
    case "moderate": return const Color(0xFFFFB547);
    default:         return const Color(0xFF2DD4A0);
  }
}

Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case "completed":   return const Color(0xFF2DD4A0);
    case "in progress": return const Color(0xFFFF6B2B);
    case "assigned":    return const Color(0xFF4A90E2);
    case "verified":    return const Color(0xFFB47EFF);
    case "received":    return const Color(0xFFFFB547);
    default:            return Colors.white.withOpacity(0.5);
  }
}

const _months = ["Jan","Feb","Mar","Apr","May","Jun",
                  "Jul","Aug","Sep","Oct","Nov","Dec"];

String _timeStr(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  return "$h:${m} ${dt.hour < 12 ? 'AM' : 'PM'}";
}

String _formatTs(String? tsMs) {
  if (tsMs == null) return "";
  final ts = int.tryParse(tsMs);
  if (ts == null) return "";
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  return "${dt.day} ${_months[dt.month - 1]}, ${_timeStr(dt)}";
}

String _timeAgo(String? tsMs) {
  if (tsMs == null) return "";
  final ts = int.tryParse(tsMs);
  if (ts == null) return "";
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (diff.inDays > 30)  return "${(diff.inDays / 30).floor()}mo ago";
  if (diff.inDays > 0)   return "${diff.inDays}d ago";
  if (diff.inHours > 0)  return "${diff.inHours}h ago";
  if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
  return "Just now";
}

String _shortDate(String tsMs) {
  final ts = int.tryParse(tsMs);
  if (ts == null) return "";
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  return "${dt.day} ${_months[dt.month - 1]}";
}

// ─────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────

class TrackComplaints extends StatefulWidget {
  const TrackComplaints({super.key});

  @override
  State<TrackComplaints> createState() => _TrackComplaintsState();
}

class _TrackComplaintsState extends State<TrackComplaints>
    with TickerProviderStateMixin {

  final _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://patha-2305-default-rtdb.asia-southeast1.firebasedatabase.app/",
  ).ref("reports");

  Map<String, dynamic>? _data;
  String? _id;
  bool _loading = true;
  bool _loadStarted = false; // guard: only load once

  late AnimationController _fadeCtrl;
  late AnimationController _progressCtrl;
  final List<AnimationController> _stageCtrl = [];

  // ─────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    for (int i = 0; i < _stages.length; i++) {
      _stageCtrl.add(AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450)));
    }

    // ✅ FIX 1: postFrameCallback guarantees ModalRoute is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loadStarted) {
        _loadStarted = true;
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _progressCtrl.dispose();
    for (final c in _stageCtrl) c.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;

    // ── Try args first (came from Complaints page) ──
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map) {
      final argMap = Map<String, dynamic>.from(args);
      final raw = argMap["data"];
      if (raw != null && raw is Map && (raw as Map).isNotEmpty) {
        _id   = argMap["id"]?.toString();
        _data = Map<String, dynamic>.from(raw);
        _finishLoading();
        return;
      }
    }

    // ── No args: fetch latest complaint from Firebase ──
    // ✅ FIX 2: Fetch all entries, sort keys numerically, pick last
    try {
      final snap = await _dbRef.get();
      if (snap.exists && snap.value != null) {
        final raw = Map<dynamic, dynamic>.from(snap.value as Map);

        // Keys are epoch-ms strings — sort numerically to get latest
        final sortedKeys = raw.keys.toList()
          ..sort((a, b) {
            final ia = int.tryParse(a.toString()) ?? 0;
            final ib = int.tryParse(b.toString()) ?? 0;
            return ia.compareTo(ib);
          });

        final latestKey = sortedKeys.last;
        final latestVal = raw[latestKey];

        if (latestVal != null && latestVal is Map) {
          _id   = latestKey.toString();
          _data = Map<String, dynamic>.from(latestVal);
        }
      }
    } catch (e) {
      debugPrint("TrackComplaints Firebase error: $e");
    }

    _finishLoading();
  }

  void _finishLoading() {
    if (!mounted) return;
    setState(() => _loading = false);
    _runAnimations();
  }

  Future<void> _runAnimations() async {
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _progressCtrl.forward();
    final active = _stageIndex(_data?["status"]?.toString() ?? "reported");
    for (int i = 0; i <= active && i < _stageCtrl.length; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) _stageCtrl[i].forward();
    }
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
          // ✅ FIX 3: activeRoute matches the key used in main.dart
          // Make sure your main.dart has: '/TrackComplaints': (_) => const TrackComplaints()
          // And all navItem routes pointing here use '/TrackComplaints'
          PathaHeader(
            activeRoute: '/TrackComplaints',
            navItems: const [
              {'label': 'Home',       'route': '/home'},
              {'label': 'Report',     'route': '/reports'},
              {'label': 'Complaints', 'route': '/complaints'},
              {'label': 'Map',        'route': '/map'},
            ],
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF6B2B)))
                : _data == null
                    ? _emptyState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded,
              size: 60, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 18),
          Text("No complaints yet",
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 6),
          Text("Go to Report page to submit one",
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.2))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/reports'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFF6B2B).withOpacity(0.4)),
              ),
              child: Text("Report an Issue",
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFFF6B2B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // MAIN CONTENT
  // ─────────────────────────────────────────

  Widget _buildContent() {
    final data     = _data!;
    final type     = data["type"]?.toString() ?? "Unknown";
    final location = data["location"]?.toString() ?? "—";
    final severity = data["severity"]?.toString() ?? "—";
    final status   = data["status"]?.toString() ?? "Reported";
    final comment  = data["comment"]?.toString() ?? "";
    final tsMain   = data["timestamp"]?.toString();
    final imgList  = data["images"];
    final hasImg   = imgList is List && imgList.isNotEmpty &&
                     imgList[0].toString().isNotEmpty;

    final activeIdx = _stageIndex(status);
    final stagesDone = activeIdx + 1;

    return FadeTransition(
      opacity: _fadeCtrl,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── HERO IMAGE / TOP BAR ─────────────
          SliverToBoxAdapter(
            child: hasImg
                ? _heroImage(imgList[0].toString())
                : _topBar(),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── TITLE + STATUS ───────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                )),
                            if (tsMain != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                "Submitted ${_timeAgo(tsMain)}  ·  ${_formatTs(tsMain)}",
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _statusBadge(status),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── DETAILS CARD ─────────────
                  _detailsCard(location, severity, comment),

                  const SizedBox(height: 22),

                  // ── PROGRESS BAR ─────────────
                  _progressCard(activeIdx, stagesDone, status),

                  const SizedBox(height: 28),

                  // ── SECTION LABEL ────────────
                  _sectionLabel("COMPLAINT JOURNEY"),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),

          // ── TIMELINE ─────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _timelineRow(i, activeIdx, data),
              ),
              childCount: _stages.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HERO IMAGE (when complaint has photo)
  // ─────────────────────────────────────────

  Widget _heroImage(String url) {
    return Stack(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [const Color(0xFF0F172A), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 14, left: 16,
          child: _backButton(),
        ),
      ],
    );
  }

  // top bar when no image
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _backButton(),
          const SizedBox(width: 12),
          Text("Complaint Details",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 16),
      ),
    );
  }

  // ─────────────────────────────────────────
  // DETAILS CARD
  // ─────────────────────────────────────────

  Widget _detailsCard(String location, String severity, String comment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          _detRow(Icons.location_on_rounded,
              const Color(0xFFFF6B2B), "Location", location),
          _divider(),
          _detRow(Icons.bar_chart_rounded,
              _severityColor(severity), "Severity", severity),
          if (_id != null) ...[
            _divider(),
            _detRow(Icons.tag_rounded,
                Colors.white.withOpacity(0.35), "ID", _id!),
          ],
          if (comment.isNotEmpty) ...[
            _divider(),
            _detRow(Icons.notes_rounded,
                const Color(0xFF4A90E2), "Note", comment),
          ],
        ],
      ),
    );
  }

  Widget _detRow(IconData icon, Color col, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: col),
          const SizedBox(width: 10),
          Text("$label  ",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.white.withOpacity(0.38))),
          Expanded(
            child: Text(val,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(color: Colors.white.withOpacity(0.06), height: 14);

  // ─────────────────────────────────────────
  // PROGRESS CARD
  // ─────────────────────────────────────────

  Widget _progressCard(int activeIdx, int stagesDone, String status) {
    final remaining = _stages.length - 1 - activeIdx;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: "Current:  ",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.38))),
                  TextSpan(
                      text: status,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remaining == 0
                      ? const Color(0xFF2DD4A0).withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  remaining > 0
                      ? "$remaining step${remaining > 1 ? 's' : ''} remaining"
                      : "✓  All done",
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: remaining == 0
                          ? const Color(0xFF2DD4A0)
                          : Colors.white.withOpacity(0.35)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented bar
          Row(
            children: List.generate(_stages.length, (i) {
              final done = i <= activeIdx;
              final isAct = i == activeIdx;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (_, __) => AnimatedContainer(
                          duration:
                              Duration(milliseconds: 250 + i * 70),
                          height: isAct ? 8 : 6,
                          decoration: BoxDecoration(
                            color: done
                                ? isAct
                                    ? const Color(0xFFFF6B2B)
                                    : const Color(0xFF2DD4A0)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    if (i < _stages.length - 1)
                      const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Labels
          Row(
            children: List.generate(_stages.length, (i) {
              final isAct = i == activeIdx;
              final done  = i < activeIdx;
              return Expanded(
                child: Text(
                  _stages[i].label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight:
                        isAct ? FontWeight.w700 : FontWeight.w400,
                    color: isAct
                        ? const Color(0xFFFF6B2B)
                        : done
                            ? Colors.white.withOpacity(0.45)
                            : Colors.white.withOpacity(0.18),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // TIMELINE ROW
  // ─────────────────────────────────────────

  Widget _timelineRow(int i, int activeIdx, Map<String, dynamic> data) {
    final stage  = _stages[i];
    final isDone = i <= activeIdx;
    final isAct  = i == activeIdx;
    final isPend = i > activeIdx;
    final isLast = i == _stages.length - 1;

    final tsKey     = "ts_${stage.key.replaceAll(' ', '_')}";
    final stageTs   = data[tsKey]?.toString();
    final displayTs = (i == 0) ? data["timestamp"]?.toString() : stageTs;

    final nodeColor = isAct
        ? const Color(0xFFFF6B2B)
        : isDone
            ? const Color(0xFF2DD4A0)
            : Colors.white.withOpacity(0.12);

    final ctrl = i < _stageCtrl.length
        ? _stageCtrl[i]
        : AnimationController(vsync: this, value: 1);

    return FadeTransition(
      opacity: ctrl,
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0.1, 0), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: ctrl, curve: Curves.easeOutCubic)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── NODE + LINE ────────────────
              SizedBox(
                width: 54,
                child: Column(
                  children: [
                    // Date above node
                    SizedBox(
                      height: 18,
                      child: displayTs != null && isDone
                          ? Text(_shortDate(displayTs),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: nodeColor))
                          : null,
                    ),
                    const SizedBox(height: 3),

                    _StageNode(
                      color: nodeColor,
                      icon: isDone && !isAct
                          ? Icons.check_rounded
                          : stage.icon,
                      isActive: isAct,
                    ),

                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDone && !isAct
                                  ? [
                                      const Color(0xFF2DD4A0),
                                      const Color(0xFF2DD4A0)
                                          .withOpacity(0.25),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.07),
                                      Colors.white.withOpacity(0.03),
                                    ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── CARD ───────────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      top: 2, bottom: isLast ? 0 : 14),
                  child: _StageCard(
                    stage: stage,
                    isActive: isAct,
                    isDone: isDone,
                    isPending: isPend,
                    timeAgo: displayTs != null ? _timeAgo(displayTs) : null,
                    fullDate: displayTs != null ? _formatTs(displayTs) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // MICRO HELPERS
  // ─────────────────────────────────────────

  Widget _statusBadge(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.45)),
      ),
      child: Text(status,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
              color: const Color(0xFFFF6B2B),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: Colors.white.withOpacity(0.32))),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// STAGE NODE (pulsing glow when active)
// ─────────────────────────────────────────────

class _StageNode extends StatefulWidget {
  final Color color;
  final IconData icon;
  final bool isActive;

  const _StageNode({
    required this.color,
    required this.icon,
    required this.isActive,
  });

  @override
  State<_StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<_StageNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.isActive) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: widget.isActive ? 1.0 + _pulse.value * 0.12 : 1.0,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.12),
            border: Border.all(
                color: widget.color,
                width: widget.isActive ? 2.5 : 1.5),
            boxShadow: widget.isActive
                ? [BoxShadow(
                    color: widget.color.withOpacity(0.35),
                    blurRadius: 14, spreadRadius: 2)]
                : null,
          ),
          child: Icon(widget.icon, color: widget.color, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STAGE CARD
// ─────────────────────────────────────────────

class _StageCard extends StatelessWidget {
  final _Stage stage;
  final bool isActive;
  final bool isDone;
  final bool isPending;
  final String? timeAgo;
  final String? fullDate;

  const _StageCard({
    required this.stage,
    required this.isActive,
    required this.isDone,
    required this.isPending,
    this.timeAgo,
    this.fullDate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1A2E45)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFF6B2B).withOpacity(0.45)
              : isDone
                  ? const Color(0xFF2DD4A0).withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(
                color: const Color(0xFFFF6B2B).withOpacity(0.07),
                blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stage.label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPending
                          ? Colors.white.withOpacity(0.22)
                          : Colors.white,
                    )),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B2B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text("ACTIVE",
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFF6B2B),
                          letterSpacing: 1.2)),
                ),
              if (isDone && !isActive)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2DD4A0), size: 16),
            ],
          ),

          if (isDone && fullDate != null) ...[
            const SizedBox(height: 7),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 11,
                      color: Colors.white.withOpacity(0.28)),
                  const SizedBox(width: 5),
                  Text("$fullDate  ·  $timeAgo",
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.38))),
                ],
              ),
            ),
          ],

          if (isPending) ...[
            const SizedBox(height: 5),
            Text("Awaiting",
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.16))),
          ],
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  double scrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        scrollPosition = _scrollController.offset.clamp(0, 1400);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isMobile = screen.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Stack(
          children: [

            // ── SCROLL CONTENT ─────────────────────
            // Add top padding so content doesn't hide under header
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Space for header
                  SizedBox(height: isMobile ? 110 : 80),

                  buildSection(
                    context,
                    "assets/images/reports.jpg",
                    false,
                    "Spotted a damaged road?",
                    "Report it instantly and improve your city.",
                    "Report Now",
                    () => Navigator.pushNamed(context, '/reports'),
                  ),

                  buildSection(
                    context,
                    "assets/videos/map.mp4",
                    true,
                    "Track your complaints",
                    "Stay updated with your reports.",
                    "Track Now",
                    () => Navigator.pushNamed(context, '/TrackComplaints'),
                  ),

                  buildSection(
                    context,
                    "assets/images/map.jpg",
                    false,
                    "Live Road Intelligence",
                    "Explore real-time road conditions.",
                    "Open Map",
                    () => Navigator.pushNamed(context, '/map'),
                  ),

                  buildSection(
                    context,
                    "assets/videos/myComp.gif",
                    false,
                    "Make your city better",
                    "Every report contributes to safer roads.",
                    "View Complaints",
                    () => Navigator.pushNamed(context, '/complaints'),
                  ),
                ],
              ),
            ),

            // ── HEADER ─────────────────────────────
            // On MOBILE: logo top-left, navbar below it (two rows)
            // On WEB:    logo top-left, navbar centered (one row, your original style)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: isMobile
                  ? _mobileHeader(context)
                  : _webHeader(context),
            ),

            // ── ROAD + PIN ──────────────────────────
            Positioned(
              right: 5,
              top: 0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenHeight = constraints.maxHeight;
                  final progress = (scrollPosition / 1400).clamp(0.0, 1.0);
                  final pinPosition = 100 + (progress * (screenHeight - 200));

                  return SizedBox(
                    width: screen.width * 0.08,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: 100,
                          child: SizedBox(
                            height: screenHeight - 200,
                            width: screen.width * 0.035,
                            child: Image.asset(
                              "assets/images/road.png",
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        Positioned(
                          top: pinPosition,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // MOBILE HEADER — 2 rows: logo row + nav row
  // ─────────────────────────────────────────
  Widget _mobileHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/images/logo.png", height: 22),
                const SizedBox(width: 5),
                Text(
                  "PATHA",
                  style: GoogleFonts.pacifico(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Row 2: Navbar centered
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  navItem("Report",     '/reports'),
                  navItem("Track",      '/TrackComplaints'),
                  navItem("Complaints", '/complaints'),
                  navItem("Map",        '/map'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // WEB HEADER — original single-row style
  // ─────────────────────────────────────────
  Widget _webHeader(BuildContext context) {
    return Stack(
      children: [
        // Gradient fade
        Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Logo — left
        Positioned(
          top: 15,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Image.asset("assets/images/logo.png", height: 26),
                const SizedBox(width: 6),
                Text(
                  "PATHA",
                  style: GoogleFonts.pacifico(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Navbar — centered (your original style)
        Positioned(
          top: 15,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  navItem("Report",     '/reports'),
                  navItem("Track",      '/TrackComplaints'),
                  navItem("Complaints", '/complaints'),
                  navItem("Map",        '/map'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // NAV ITEM
  // ─────────────────────────────────────────
  Widget navItem(String title, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SECTION BUILDER — unchanged
  // ─────────────────────────────────────────
  Widget buildSection(
    BuildContext context,
    String path,
    bool isVideo,
    String title,
    String subtitle,
    String buttonText,
    VoidCallback onTap,
  ) {
    final screen = MediaQuery.of(context).size;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      height: screen.height * 0.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            isVideo
                ? BackgroundVideo(videoPath: path)
                : Image.asset(path, fit: BoxFit.cover),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: screen.width * 0.06),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  width: screen.width * 0.65,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: onTap,
                        child: Text(buttonText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// VIDEO WIDGET — unchanged
// ─────────────────────────────────────────────
class BackgroundVideo extends StatefulWidget {
  final String videoPath;
  const BackgroundVideo({super.key, required this.videoPath});

  @override
  State<BackgroundVideo> createState() => _BackgroundVideoState();
}

class _BackgroundVideoState extends State<BackgroundVideo> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        controller.setLooping(true);
        controller.setVolume(0);
        controller.play();
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return const SizedBox();
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
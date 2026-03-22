// lib/widgets/patha_header.dart
// ✅ WEB:    Stack layout — logo left, navbar pill CENTERED (matches home.dart)
// ✅ MOBILE: Row layout  — logo left, navbar scrollable right (no overlap, no overflow)
// ✅ SafeArea on both so never goes under status bar

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PathaHeader extends StatelessWidget {
  final String activeRoute;
  final List<Map<String, String>> navItems;

  const PathaHeader({
    super.key,
    required this.activeRoute,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SafeArea(
      bottom: false,
      child: isMobile ? _mobileHeader(context) : _webHeader(context),
    );
  }

  // ─────────────────────────────────────────
  // WEB — logo left, navbar centered pill
  // Matches home.dart style exactly
  // ─────────────────────────────────────────
  Widget _webHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Logo — left
          Positioned(
            left: 0,
            child: _logo(),
          ),
          // Navbar — centered
          Center(
            child: _navPill(context, 13),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // MOBILE — logo left, nav scrollable right
  // No Stack = no overlap ever
  // ─────────────────────────────────────────
  Widget _mobileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Logo
          _logo(mobile: true),

          const SizedBox(width: 8),

          // Nav — takes remaining space, scrolls if needed
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // align items to the right naturally
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: navItems
                    .map((item) => _navItem(
                          context,
                          item['label']!,
                          item['route']!,
                          fontSize: 11,
                          hPad: 9,
                          vPad: 5,
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────

  Widget _logo({bool mobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 12,
        vertical: mobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset("assets/images/logo.png",
              height: mobile ? 18 : 24),
          const SizedBox(width: 5),
          Text(
            "PATHA",
            style: GoogleFonts.pacifico(
              fontSize: mobile ? 13 : 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navPill(BuildContext context, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: navItems
            .map((item) => _navItem(
                  context,
                  item['label']!,
                  item['route']!,
                  fontSize: fontSize,
                ))
            .toList(),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String label,
    String route, {
    double fontSize = 13,
    double hPad = 14,
    double vPad = 6,
  }) {
    final isActive = activeRoute == route;
    return GestureDetector(
      onTap: () {
        if (!isActive) Navigator.pushNamed(context, route);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFFFF6B2B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF6B2B).withOpacity(0.6),
                ),
              )
            : null,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isActive
                ? const Color(0xFFFF6B2B)
                : Colors.white,
            fontSize: fontSize,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
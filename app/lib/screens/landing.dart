import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {

  final List<String> images = [
    "assets/images/img1.jpg",
    "assets/images/img2.jpg",
    "assets/images/img3.jpg",
  ];

  late String selectedImage;

  @override
  void initState() {
    super.initState();
    final random = Random();
    selectedImage = images[random.nextInt(images.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // BACKGROUND IMAGE
          SizedBox.expand(
            child: Image.asset(
              selectedImage,
              fit: BoxFit.cover,
            ),
          ),

          // DARK OVERLAY
          Container(
            color: Colors.black.withOpacity(0.25),
          ),

          // LOGO + PATHA (TOP LEFT)
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              children: [

                Image.asset(
                  "assets/images/logo.png",
                  height: 50,
                ),

                const SizedBox(width: 10),

                Text(
                  "PATHA",
                  style: GoogleFonts.pacifico(
                    fontSize: 28,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // MAIN CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // BIG TEXT
                Text(
                  "Track",
                  style: GoogleFonts.bungee(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: Colors.tealAccent[400],
                  ),
                ),

                Text(
                  "Report",
                  style: GoogleFonts.bungee(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                Text(
                  "Improve",
                  style: GoogleFonts.bungee(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: Colors.orangeAccent,
                  ),
                ),

                const SizedBox(height: 60),

                Text(
                  "Smarter roads for Solapur",
                  style: GoogleFonts.changaOne(
                    fontSize: 18,
                    color: const Color.fromARGB(255, 219, 210, 210),
                  ),
                ),

                const SizedBox(height: 40),

                // GLASS BUTTON
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/home');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          "Let's Go →",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SCROLL INDICATOR
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Icon(Icons.keyboard_arrow_up,
                    color: Colors.white, size: 35),
                SizedBox(height: 5),
                Text(
                  "Swipe Up",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
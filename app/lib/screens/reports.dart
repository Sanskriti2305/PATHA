import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:app/widgets/patha_header.dart';

const _cloudName    = 'djbea9qle';
const _uploadPreset = 'patha_upload';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> images = [];

  String severity      = "";
  String selectedType  = "";
  double? latitude;
  double? longitude;
  bool _isSubmitting   = false;
  bool _locationLoading = false;
  bool _manualLocation = false;   // switched to manual input

  // Location text — either auto-fetched or typed by user
  final _locationCtrl  = TextEditingController(text: "");
  final commentController = TextEditingController();

  final dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://patha-2305-default-rtdb.asia-southeast1.firebasedatabase.app/",
  ).ref("reports");

  final damageTypes = ["Pothole", "Crack", "Waterlogging", "Other"];
  final _severityConfig = const {
    "Minor":    Color(0xFF2DD4A0),
    "Moderate": Color(0xFFFFB547),
    "Severe":   Color(0xFFFF4D4D),
  };

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  @override
  void dispose() {
    commentController.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // LOCATION — final fix
  // Uses browser navigator.geolocation directly via Geolocator
  // Reverse geocode via FREE Nominatim API (no key needed) — works on Web
  // Falls back to manual input if anything fails
  // ─────────────────────────────────────────
  Future<void> getLocation() async {
    setState(() { _locationLoading = true; _manualLocation = false; });

    try {
      // Step 1: Check/request permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _setManual();
        return;
      }
      if (perm == LocationPermission.denied) {
        _setManual();
        return;
      }

      // Step 2: Get coordinates
      // Use .timeout() wrapper instead of timeLimit param (works on both web+mobile)
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low, // low = fastest, good enough for address
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception("Location timed out"),
        );
      } catch (e) {
        debugPrint("GPS failed: $e");
        // Try last known position as fallback (mobile only)
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            pos = last;
            debugPrint("Using last known position");
          } else {
            _setManual();
            return;
          }
        } catch (_) {
          _setManual();
          return;
        }
      }

      latitude  = pos.latitude;
      longitude = pos.longitude;
      debugPrint("✅ Got coords: $latitude, $longitude");

      // Step 3: Reverse geocode via Nominatim (FREE, works on Flutter Web)
      // geocoding package does NOT work on web — use http directly
      try {
        final url = Uri.parse(
          "https://nominatim.openstreetmap.org/reverse"
          "?lat=${latitude}&lon=${longitude}&format=json",
        );
        final response = await http.get(url, headers: {
          "User-Agent": "PATHA-App/1.0",
          "Accept-Language": "en",
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final addr = data["address"] as Map<String, dynamic>? ?? {};

          // Build readable address from Nominatim response
          final parts = [
            addr["road"],
            addr["suburb"],
            addr["neighbourhood"],
            addr["city"] ?? addr["town"] ?? addr["village"],
            addr["state"],
          ].where((s) => s != null && s.toString().isNotEmpty)
           .map((s) => s.toString())
           .toList();

          final readableAddr = parts.isNotEmpty
              ? parts.take(3).join(", ")
              : "${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}";

          debugPrint("✅ Address: $readableAddr");
          setState(() {
            _locationCtrl.text = readableAddr;
            _locationLoading   = false;
          });
        } else {
          // Nominatim failed — show raw coords, still valid for map
          setState(() {
            _locationCtrl.text =
                "${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}";
            _locationLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Reverse geocode failed: $e");
        // Still have valid coords — show them
        setState(() {
          _locationCtrl.text =
              "${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}";
          _locationLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Location error: $e");
      _setManual();
    }
  }

  void _setManual() {
    setState(() {
      _locationLoading = false;
      _manualLocation  = true;
      _locationCtrl.text = "";
    });
  }

  // ─────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────
  Future<void> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final picked = await _picker.pickImage(source: source, imageQuality: 80);
        if (picked != null) setState(() => images.add(picked));
      } else {
        final picked = await _picker.pickMultiImage(imageQuality: 80);
        if (picked.isNotEmpty) setState(() => images.addAll(picked));
      }
    } catch (e) {
      _snack("Image picker error: $e");
    }
  }

  // ─────────────────────────────────────────
  // CLOUDINARY UPLOAD
  // ─────────────────────────────────────────
  Future<List<String>> _uploadImages() async {
    if (images.isEmpty) return [];

    // ⚠️ Catch placeholder credentials early
    if (_cloudName == 'YOUR_CLOUD_NAME' || _uploadPreset == 'YOUR_PRESET') {
      _snack("❌ Set your Cloudinary credentials at top of reports.dart");
      return [];
    }

    final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
    final List<String> urls = [];

    for (final img in images) {
      try {
        final bytes = await img.readAsBytes();
        final req = http.MultipartRequest('POST', Uri.parse(url))
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file', bytes, filename: img.name));

        final streamed = await req.send();
        final body     = await streamed.stream.bytesToString();

        if (streamed.statusCode == 200) {
          final decoded = jsonDecode(body);
          final secureUrl = decoded['secure_url']?.toString();
          if (secureUrl != null) {
            urls.add(secureUrl);
            debugPrint("✅ Cloudinary upload OK: $secureUrl");
          }
        } else {
          // Show real error from Cloudinary response
          debugPrint("❌ Cloudinary error ${streamed.statusCode}: $body");
          _snack("Image upload failed (${streamed.statusCode}). Check credentials.");
        }
      } catch (e) {
        debugPrint("❌ Upload exception: $e");
        _snack("Upload error: $e");
      }
    }
    return urls;
  }

  // ─────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────
  Future<void> submitReport() async {
    final locationVal = _locationCtrl.text.trim();

    if (selectedType.isEmpty) { _snack("Please select a damage type"); return; }
    if (severity.isEmpty)     { _snack("Please select severity level"); return; }
    if (locationVal.isEmpty)  { _snack("Please enter your location");   return; }

    setState(() => _isSubmitting = true);
    try {
      // ✅ If lat/lng missing (manual input), geocode via Nominatim
      if (latitude == null || longitude == null) {
        try {
          final encoded = Uri.encodeComponent(locationVal);
          final url = Uri.parse(
            "https://nominatim.openstreetmap.org/search"
            "?q=$encoded&format=json&limit=1",
          );
          final res = await http.get(url, headers: {
            "User-Agent": "PATHA-App/1.0",
          });
          if (res.statusCode == 200) {
            final list = jsonDecode(res.body) as List;
            if (list.isNotEmpty) {
              latitude  = double.tryParse(list[0]["lat"].toString());
              longitude = double.tryParse(list[0]["lon"].toString());
              debugPrint("✅ Geocoded manual address: $latitude, $longitude");
            }
          }
        } catch (e) {
          debugPrint("Manual geocode failed: $e");
        }
      }

      final uploadedUrls = await _uploadImages();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await dbRef.child(id).set({
        "images":    uploadedUrls,
        "latitude":  latitude,
        "longitude": longitude,
        "location":  locationVal,
        "type":      selectedType,
        "severity":  severity,
        "comment":   commentController.text.trim(),
        "status":    "Reported",
        "timestamp": id,
      });

      debugPrint("✅ Firebase write OK, id=$id, images=${uploadedUrls.length}");

      setState(() {
        images.clear();
        severity      = "";
        selectedType  = "";
        commentController.clear();
      });
      getLocation(); // refresh location for next report
      _snack("✅ Report submitted! Images: ${uploadedUrls.length}");
    } catch (e) {
      debugPrint("❌ Firebase submit error: $e");
      _snack("Submission failed: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
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
          PathaHeader(
            activeRoute: '/reports',
            navItems: const [
              {'label': 'Home',       'route': '/home'},
              {'label': 'Track',      'route': '/TrackComplaints'},
              {'label': 'Complaints', 'route': '/complaints'},
              {'label': 'Map',        'route': '/map'},
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text("Report an Issue",
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("Help us fix Solapur's roads faster",
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.38))),

                  const SizedBox(height: 28),

                  // ── PHOTOS ──────────────────
                  _sectionLabel("Photos", Icons.photo_camera_rounded),
                  const SizedBox(height: 12),
                  Row(children: [
                    _imgBtn("Camera",  Icons.camera_alt_rounded,   ImageSource.camera),
                    const SizedBox(width: 10),
                    _imgBtn("Gallery", Icons.photo_library_rounded, ImageSource.gallery),
                  ]),
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (_, i) => _thumb(i),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── LOCATION ────────────────
                  _sectionLabel("Location", Icons.location_on_rounded),
                  const SizedBox(height: 10),
                  _locationField(),

                  const SizedBox(height: 24),

                  // ── DAMAGE TYPE ─────────────
                  _sectionLabel("Damage Type", Icons.warning_amber_rounded),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A2E45),
                        hint: Text("Select type",
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.38),
                                fontSize: 13)),
                        value: selectedType.isEmpty ? null : selectedType,
                        items: damageTypes.map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => selectedType = v ?? ""),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── SEVERITY ────────────────
                  _sectionLabel("Severity", Icons.bar_chart_rounded),
                  const SizedBox(height: 10),
                  Row(
                    children: _severityConfig.entries
                        .map((e) => _severityChip(e.key, e.value))
                        .toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── COMMENT ─────────────────
                  _sectionLabel("Additional Details", Icons.notes_rounded),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: TextField(
                      controller: commentController,
                      maxLines: 3,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Describe the issue (optional)...",
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.3), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── SUBMIT ──────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B2B),
                        disabledBackgroundColor:
                            const Color(0xFFFF6B2B).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text("Submit Report",
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // LOCATION FIELD WIDGET
  // ─────────────────────────────────────────
  Widget _locationField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _manualLocation
              ? const Color(0xFFFF6B2B).withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded,
              color: _manualLocation
                  ? const Color(0xFFFF6B2B)
                  : const Color(0xFF2DD4A0),
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: _locationLoading
                ? Row(children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2DD4A0))),
                    const SizedBox(width: 8),
                    Text("Fetching location...",
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 13)),
                  ])
                : TextField(
                    controller: _locationCtrl,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: _manualLocation
                          ? "e.g. Hotgi Road, Solapur"
                          : "Location",
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13),
                    ),
                  ),
          ),
          // Retry / manual toggle button
          if (!_locationLoading)
            GestureDetector(
              onTap: getLocation,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.my_location_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.45)),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────
  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 15, color: const Color(0xFFFF6B2B)),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 0.3)),
    ]);
  }

  Widget _imgBtn(String label, IconData icon, ImageSource source) {
    return Expanded(
      child: GestureDetector(
        onTap: () => pickImage(source),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFF6B2B), size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.6), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(int i) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 100, height: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.network(images[i].path, fit: BoxFit.cover)
                : Image.file(File(images[i].path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4, right: 14,
          child: GestureDetector(
            onTap: () => setState(() => images.removeAt(i)),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _severityChip(String label, Color color) {
    final isSelected = severity == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => severity = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.white.withOpacity(0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? color : Colors.white.withOpacity(0.38))),
          ),
        ),
      ),
    );
  }
}


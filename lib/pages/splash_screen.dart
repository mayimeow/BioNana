import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/pages/main_page.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // --- YOUR COLORS ---
  final Color bioGreen = const Color(0xFF266533);
  final Color nanaYellow = const Color(0xFFE2CA19);

  @override
  void initState() {
    super.initState();
    // 5 Seconds Load Time
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });

    _startLoadingProcess();
  }

  Future<void> _startLoadingProcess() async {
    _controller.forward();

    try {
      await FirebaseAuth.instance.signInAnonymously();

      if (_controller.isAnimating) {
        await Future.delayed(Duration(
            milliseconds: (_controller.duration!.inMilliseconds -
                    _controller.value * _controller.duration!.inMilliseconds)
                .toInt()));
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainPage()),
        );
      }
    } catch (e) {
      _controller.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection Error: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // --- MAIN LOGO (Top) ---
              Image.asset(
                'assets/images/logo.png',
                width: 220,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 10),

              // --- TEXT TITLE (BioNana) ---
              RichText(
                text: TextSpan(
                  style: GoogleFonts.geologica(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(text: "Bio", style: TextStyle(color: bioGreen)),
                    TextSpan(text: "Nana", style: TextStyle(color: nanaYellow)),
                  ],
                ),
              ),

              const Spacer(),

              // --- LOADING BAR AREA ---
              LayoutBuilder(
                builder: (context, constraints) {
                  final double barWidth = constraints.maxWidth;
                  final double iconSize = 28.0; 
                  
                  // Calculate position
                  final double leftPosition = (barWidth * _controller.value) - (iconSize / 2);

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Gray Background
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      
                      // Yellow Progress Fill
                      Container(
                        height: 8,
                        width: barWidth * _controller.value,
                        decoration: BoxDecoration(
                          color: nanaYellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // --- THE SIMPLE BANANA ICON ---
                      Positioned(
                        left: leftPosition.clamp(0, barWidth - iconSize),
                        bottom: 8, // Sits slightly above the bar
                        child: Transform.rotate(
                          angle: 0.2, // Slight tilt
                          child: CustomPaint(
                            size: Size(iconSize, iconSize),
                            painter: SimpleBananaPainter(nanaYellow, bioGreen),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              Text(
                "loading ...",
                style: GoogleFonts.geologica(
                  fontSize: 14,
                  color: Colors.grey[400],
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CUSTOM PAINTER FOR SIMPLE BANANA ---
// This draws a cute banana shape mathematically so you don't need an image file.
class SimpleBananaPainter extends CustomPainter {
  final Color yellow;
  final Color green;

  SimpleBananaPainter(this.yellow, this.green);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = yellow
      ..style = PaintingStyle.fill;

    // 1. Draw the Banana Body (Curved Crescent)
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 1.1, // Control point (bottom curve)
      size.width * 0.9, size.height * 0.2, // End point
    );
    path.quadraticBezierTo(
      size.width * 0.6, size.height * 0.7, // Control point (inner curve)
      size.width * 0.1, size.height * 0.3, // Back to start
    );
    path.close();
    canvas.drawPath(path, paint);

    // 2. Draw the Stem (Green Tip)
    final stemPaint = Paint()..color = green;
    final stemPath = Path();
    stemPath.moveTo(size.width * 0.9, size.height * 0.2); // Start at banana tip
    stemPath.lineTo(size.width * 0.95, size.height * 0.1); // Go up/right
    stemPath.lineTo(size.width * 0.82, size.height * 0.25); // Go down slightly
    stemPath.close();
    canvas.drawPath(stemPath, stemPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'auth-process/auth.dart'; // AuthenticationPage
import 'mainbase/homepage.dart'; // HomePage
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Start(),
    );
  }
}

// ------------------- Animated Splash -------------------

class Start extends StatefulWidget {
  const Start({Key? key}) : super(key: key);

  @override
  _StartState createState() => _StartState();
}

class _StartState extends State<Start> with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late AnimationController _marketController;
  late AnimationController _sutraController;

  User? _currentUser;
  bool _hasInternet = true;
  bool _serverVerified = false;

  @override
  void initState() {
    super.initState();

    // Arrow animation
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    // Text animations
    _marketController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _sutraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _checkAppState();

    // Sequential text animations
    _arrowController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _marketController.forward();
      }
    });

    _marketController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _sutraController.forward();
      }
    });

    _sutraController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateNext();
        });
      }
    });
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _marketController.dispose();
    _sutraController.dispose();
    super.dispose();
  }

  Future<void> _checkAppState() async {
    try {
      var connectivity = await Connectivity().checkConnectivity();
      _hasInternet = connectivity != ConnectivityResult.none;

      final FirebaseAuth auth = FirebaseAuth.instance;
      _currentUser = auth.currentUser;

      if (_hasInternet && _currentUser != null) {
        var url = Uri.parse('YOUR_IP/check');
        var response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"uid": _currentUser!.uid}),
        );

        _serverVerified = response.statusCode == 200;
      } else {
        _serverVerified = false;
      }
    } catch (e) {
      print("Error during verification: $e");
      _serverVerified = false;
    }
  }

  void _navigateNext() {
    if (_currentUser != null && _serverVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthenticationPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated arrows
            AnimatedBuilder(
              animation: _arrowController,
              builder: (context, child) {
                return SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: CustomPaint(
                    painter: _StockMarketArrowsPainter(
                      progress: _arrowController.value,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // Animated MARKET-SUTRA
            AnimatedBuilder(
              animation: Listenable.merge([_marketController, _sutraController]),
              builder: (context, child) {
                const marketText = 'MARKET';
                const sutraText = 'SUTRA';

                int marketCount =
                (marketText.length * _marketController.value).floor();
                int sutraCount =
                (sutraText.length * _sutraController.value).floor();

                return RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: marketText.substring(0, marketCount),
                        style: const TextStyle(color: Colors.green),
                      ),
                      TextSpan(
                        text: sutraText.substring(0, sutraCount),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- Custom Painter -------------------

class _StockMarketArrowsPainter extends CustomPainter {
  final double progress;
  _StockMarketArrowsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final greenPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final redPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    double arrowHeadSize = 20;

    final greenPoints = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.4),
      Offset(size.width * 0.8, size.height * 0.6),
      Offset(size.width, size.height * 0.3),
    ];

    final redPoints = [
      Offset(0, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.3),
      Offset(size.width * 0.6, size.height * 0.6),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.7),
    ];

    double greenProgress = (progress <= 0.5) ? (progress / 0.5) : 1.0;
    double redProgress = (progress > 0.5) ? ((progress - 0.5) / 0.5) : 0.0;

    _drawAnimatedPath(
        canvas, greenPoints, greenPaint, greenProgress, arrowHeadSize);
    _drawAnimatedPath(
        canvas, redPoints, redPaint, redProgress, arrowHeadSize);
  }

  void _drawAnimatedPath(Canvas canvas, List<Offset> points, Paint paint,
      double progress, double arrowHeadSize) {
    if (progress <= 0) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    int totalSegments = points.length - 1;
    double animatedSegments = totalSegments * progress;

    for (int i = 0; i < animatedSegments.floor(); i++) {
      path.lineTo(points[i + 1].dx, points[i + 1].dy);
    }

    if (animatedSegments % 1 != 0) {
      int currentIndex = animatedSegments.floor();
      double t = animatedSegments % 1;
      Offset start = points[currentIndex];
      Offset end = points[currentIndex + 1];
      Offset interpolated = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      path.lineTo(interpolated.dx, interpolated.dy);
    }

    canvas.drawPath(path, paint);

    if (progress >= 1.0) {
      _drawArrowHead(
        canvas,
        tip: points.last,
        prev: points[points.length - 2],
        paint: paint,
        size: arrowHeadSize,
      );
    }
  }

  void _drawArrowHead(Canvas canvas,
      {required Offset tip,
        required Offset prev,
        required Paint paint,
        double size = 12.0}) {
    final direction = (tip - prev).direction;

    final left = Offset.fromDirection(direction + 2.5, size);
    final right = Offset.fromDirection(direction - 2.5, size);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + left.dx, tip.dy + left.dy)
      ..lineTo(tip.dx + right.dx, tip.dy + right.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StockMarketArrowsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

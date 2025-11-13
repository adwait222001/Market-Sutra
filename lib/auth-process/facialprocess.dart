import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsutra/auth-process/details.dart'; // Make sure this import points to your Details class file

class face extends StatefulWidget {
  const face({super.key});

  @override
  State<face> createState() => _faceState();
}

class _faceState extends State<face> {
  File? image;
  final picker = ImagePicker();
  bool _isUploading = false;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomDialog(
        "Please click an image for your profile picture",
        "OK",
            () => Navigator.pop(context),
      );
    });
  }

  Future<void> _pickImage() async {
    final pickedfile = await picker.pickImage(source: ImageSource.camera);
    if (pickedfile != null) {
      setState(() {
        image = File(pickedfile.path);
      });
    }
  }

  Future<bool> uploadImage(File image, String userId) async {
    try {
      var uri = Uri.parse('YOUR_IP/image');
      var request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = userId;

      var file = await http.MultipartFile.fromPath('file', image.path);
      request.files.add(file);

      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print("Error uploading image: $e");
      return false;
    }
  }

  void showCustomDialog(String message, String buttonText, VoidCallback onPressed) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(""),
          content: SizedBox(
            height: 110,
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StockMarketArrowsPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Display picked image
                    if (image != null)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        width: double.infinity,
                        child: Image.file(
                          image!,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      const Text(
                        'No image selected',
                        style: TextStyle(fontSize: 18),
                      ),
                    const SizedBox(height: 20),

                    // Pick Image button (visible only if no image)
                    if (image == null)
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: const Text("Pick Image"),
                      ),

                    // Upload & Cancel buttons (visible only if image selected)
                    if (image != null) ...[
                      ElevatedButton(
                        onPressed: () async {
                          if (user != null) {
                            setState(() {
                              _isUploading = true;
                            });
                            bool success = await uploadImage(image!, user!.uid);
                            setState(() {
                              _isUploading = false;
                            });

                            if (success) {
                              showCustomDialog(
                                "Upload successful",
                                "OK",
                                    () {
                                  Navigator.pop(context); // Close dialog
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const Details(),
                                    ),
                                  );
                                },
                              );
                            } else {
                              showCustomDialog(
                                "Upload failed",
                                "Retry",
                                    () {
                                  Navigator.pop(context);
                                  _pickImage();
                                },
                              );
                            }
                          }
                        },
                        child: _isUploading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text("Upload Image"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            image = null; // Cancel and reset
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text("Cancel"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter for two large diagonal crossing arrows
class StockMarketArrowsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final arrowWidth = 3.0;
    final arrowSize = 12.0;

    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = arrowWidth
      ..style = PaintingStyle.stroke;

    final greenPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = arrowWidth
      ..style = PaintingStyle.stroke;

    final redFill = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final greenFill = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final verticalOffset = size.height * 0.12;
    final redYOffset = size.height * 0.20;

    // RED ARROW
    final redPoints = [
      Offset(size.width * 0.05, size.height * 0.90 + redYOffset),
      Offset(size.width * 0.20, size.height * 0.70 + redYOffset),
      Offset(size.width * 0.35, size.height * 0.80 + redYOffset),
      Offset(size.width * 0.50, size.height * 0.60 + redYOffset),
      Offset(size.width * 0.65, size.height * 0.70 + redYOffset),
      Offset(size.width * 0.80, size.height * 0.50 + redYOffset),
      Offset(size.width * 0.95, size.height * 0.40 + redYOffset),
    ];

    final redPath = Path()..moveTo(redPoints.first.dx, redPoints.first.dy);
    for (int i = 1; i < redPoints.length; i++) {
      redPath.lineTo(redPoints[i].dx, redPoints[i].dy);
    }
    canvas.drawPath(redPath, redPaint);

    _drawArrowHead(
      canvas,
      tip: redPoints.last,
      prev: redPoints[redPoints.length - 2],
      paint: redFill,
      size: arrowSize,
    );

    // GREEN ARROW
    final greenPoints = [
      Offset(size.width * 0.95, size.height * 0.15 - verticalOffset),
      Offset(size.width * 0.80, size.height * 0.35 - verticalOffset),
      Offset(size.width * 0.65, size.height * 0.25 - verticalOffset),
      Offset(size.width * 0.50, size.height * 0.45 - verticalOffset),
      Offset(size.width * 0.35, size.height * 0.35 - verticalOffset),
      Offset(size.width * 0.20, size.height * 0.55 - verticalOffset),
      Offset(size.width * 0.05, size.height * 0.65 - verticalOffset),
    ];

    final greenPath = Path()..moveTo(greenPoints.first.dx, greenPoints.first.dy);
    for (int i = 1; i < greenPoints.length; i++) {
      greenPath.lineTo(greenPoints[i].dx, greenPoints[i].dy);
    }
    canvas.drawPath(greenPath, greenPaint);

    _drawArrowHead(
      canvas,
      tip: greenPoints.last,
      prev: greenPoints[greenPoints.length - 2],
      paint: greenFill,
      size: arrowSize,
    );
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

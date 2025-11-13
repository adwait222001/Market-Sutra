import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsutra/auth-process/facialprocess.dart';

class Panimage extends StatefulWidget {
  const Panimage({super.key});

  @override
  State<Panimage> createState() => _PanimageState();
}

class _PanimageState extends State<Panimage> {
  File? imageFile;
  final picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic> extractedData = {};
  Map<String, dynamic> processedData = {};
  bool isUploading = false;
  String? serverErrorMessage;

  /// Pick image
  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
        extractedData.clear();
        processedData.clear();
        serverErrorMessage = null;
      });

      uploadImage();
    }
  }

  /// Upload to Flask `/upload` and then run OCR
  Future<void> uploadImage() async {
    if (imageFile == null || user == null) return;

    setState(() {
      isUploading = true;
      serverErrorMessage = null;
    });

    var uploadUri = Uri.parse("YOUR_IP/upload");
    var request = http.MultipartRequest("POST", uploadUri);
    request.files.add(await http.MultipartFile.fromPath("file", imageFile!.path));
    request.fields["user_id"] = user!.uid;

    try {
      var response = await request.send();
      var body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> uploadData = jsonDecode(body);

        // Run OCR
        var ocrUri = Uri.parse("http://192.168.29.214:5000/process_ocr");
        var ocrResponse = await http.post(
          ocrUri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"temp_filename": uploadData['temp_filename']}),
        );

        if (ocrResponse.statusCode == 200) {
          final Map<String, dynamic> ocrData = jsonDecode(ocrResponse.body);
          setState(() {
            extractedData = {
              ...ocrData,
              "temp_filename": uploadData['temp_filename']
            };
            processData(ocrData);
            serverErrorMessage = null;
          });
        } else if (ocrResponse.statusCode == 400) {
          final Map<String, dynamic> errorData = jsonDecode(ocrResponse.body);
          setState(() {
            serverErrorMessage = errorData['message'] ??
                "Please provide a clear and correct PAN card image";
            processedData.clear();
            imageFile = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("OCR failed: ${ocrResponse.statusCode}")),
          );
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = jsonDecode(body);
        setState(() {
          serverErrorMessage = errorData['message'] ??
              "Please provide a clear and correct PAN card image";
          processedData.clear();
          imageFile = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error: $e")),
      );
    }

    setState(() => isUploading = false);
  }

  /// Convert base64 → bytes for display
  void processData(Map<String, dynamic> data) {
    Uint8List? photoBytes;
    Uint8List? signatureBytes;

    if (data['photo'] != null) {
      photoBytes = base64Decode(data['photo']);
    }
    if (data['signature'] != null) {
      signatureBytes = base64Decode(data['signature']);
    }

    processedData = {
      "name": data['name'],
      "dob": data['dob'],
      "pan": data['pan'],
      "photoBytes": photoBytes,
      "signatureBytes": signatureBytes,
    };
  }

  /// Confirm or Cancel data
  Future<void> confirmData({required String action}) async {
    if (user == null) return;

    if (action == "cancel") {
      // purely local: clear state
      setState(() {
        processedData.clear();
        extractedData.clear();
        imageFile = null;
        serverErrorMessage = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Upload canceled.")));
      return;
    }

    // action == "confirm" → send to server
    var uri = Uri.parse("http://192.168.29.214:5000/process");

    try {
      var body = {
        "action": action, // "confirm"
        "temp_filename": extractedData['temp_filename'] ?? "",
        "user_id": user!.uid,
        "name": processedData['name'],
        "dob": processedData['dob'],
        "pan": processedData['pan'],
      };

      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final Map<String, dynamic> resData = jsonDecode(response.body);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(resData['message'])));

      if (response.statusCode == 200) {
        // Navigate to face screen on confirm
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const face()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget buildOcrCard() {
    return Card(
      color: Colors.blue[400],
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/indian_emblem.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                const Text(
                  "Permanent Account Number Card:",
                  style: TextStyle(fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  processedData['pan'] ?? "",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (processedData['photoBytes'] != null)
              Image.memory(
                processedData['photoBytes']!,
                width: 150,
                height: 150,
              ),
            const SizedBox(height: 16),
            Text(
              "Name: ${processedData['name'] ?? ''}",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 16),
            if (processedData['signatureBytes'] != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Date of birth: ${processedData['dob'] ?? ''}",
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  Image.memory(
                    processedData['signatureBytes']!,
                    width: 150,
                    height: 50,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload PAN Card")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (imageFile == null || serverErrorMessage != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => pickImage(ImageSource.camera),
                    child: const Text("Camera"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => pickImage(ImageSource.gallery),
                    child: const Text("Gallery"),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (isUploading) const CircularProgressIndicator(),
            if (serverErrorMessage != null) ...[
              const SizedBox(height: 20),
              Text(
                serverErrorMessage!,
                style: const TextStyle(
                    fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            if (processedData.isNotEmpty) buildOcrCard(),
            if (processedData.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => confirmData(action: "confirm"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Confirm"),
                  ),
                  ElevatedButton(
                    onPressed: () => confirmData(action: "cancel"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

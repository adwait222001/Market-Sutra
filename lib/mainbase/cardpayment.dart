import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'homepage.dart';

class CardPayment extends StatefulWidget {
  final String company;
  final String symbol;
  final double amount;
  final String sector;
  final int shares;

  const CardPayment({
    super.key,
    required this.company,
    required this.symbol,
    required this.amount,
    required this.sector,
    required this.shares,
  });

  @override
  State<CardPayment> createState() => _CardPaymentState();
}

class _CardPaymentState extends State<CardPayment> {
  WebViewController? _controller;
  String paymentStatus = "";
  bool paymentSuccess = false;

  // ✅ Send transaction data to backend (same style as UPI)
  Future<bool> _sendTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    String uid = "0";

    if (user != null) {
      uid = user.uid;
    } else {
      print("⚠️ No Firebase user logged in, using uid = 0");
    }

    final url = Uri.parse("YOUR_IP/add_transaction");
    final body = {
      "uid": uid,
      "company": widget.company,
      "symbol": widget.symbol,
      "sector": widget.sector,
      "shares": widget.shares,
    };

    print("📤 Sending transaction to backend: $body");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      print("📥 Response code: ${response.statusCode}");
      print("📥 Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("❌ Transaction failed to send: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error sending transaction: $e");
      return false;
    }
  }

  // ✅ Start PayPal flow
  Future<void> openPayPal() async {
    try {
      final response = await http.post(
        Uri.parse('YOUR_IP/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': widget.amount.toStringAsFixed(2)}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final approvalUrl = data['approval_url'];

        if (approvalUrl != null) {
          _controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (navRequest) async {
                  // ✅ Handle PayPal success redirect
                  if (navRequest.url.contains('/return')) {
                    final uri = Uri.parse(navRequest.url);
                    final token = uri.queryParameters['token'];

                    if (token != null) {
                      final captureResp = await http.get(
                        Uri.parse('YOUR_IP/capture?token=$token'),
                      );
                      final jsonData = jsonDecode(captureResp.body);

                      setState(() {
                        paymentStatus = jsonData['status'];
                        paymentSuccess = (jsonData['status'] == "COMPLETED");
                        _controller = null; // Close WebView
                      });

                      if (paymentSuccess) {
                        bool success = await _sendTransaction();
                        if (success) {
                          _showOrderSuccessDialog();
                        } else {
                          _showErrorDialog("Payment succeeded but failed to record transaction.");
                        }
                      } else {
                        _showErrorDialog("Payment not completed.");
                      }
                    }
                    return NavigationDecision.prevent;
                  }
                  // ✅ Handle PayPal cancel redirect
                  else if (navRequest.url.contains('/cancel')) {
                    setState(() {
                      paymentStatus = "CANCELLED";
                      paymentSuccess = false;
                      _controller = null;
                    });
                    _showErrorDialog("Payment cancelled.");
                    return NavigationDecision.prevent;
                  }

                  return NavigationDecision.navigate;
                },
              ),
            )
            ..loadRequest(Uri.parse(approvalUrl));

          setState(() {});
        } else {
          print("❌ No approval URL returned from backend.");
        }
      } else {
        print("❌ Failed to create PayPal order: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error opening PayPal: $e");
    }
  }

  // ✅ Success dialog
  void _showOrderSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Transaction Successful ✅"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              'https://cdn-icons-png.flaticon.com/512/845/845646.png',
              width: 80,
              height: 80,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You have paid ₹${widget.amount.toStringAsFixed(2)} "
                  "for ${widget.shares} shares of ${widget.company} "
                  "(${widget.symbol}) in ${widget.sector} sector.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ✅ Error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    openPayPal(); // ✅ Automatically open PayPal flow
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Credit/Debit Card Payment")),
      body: _controller != null
          ? WebViewWidget(controller: _controller!)
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Processing payment..."),
          ],
        ),
      ),
    );
  }
}

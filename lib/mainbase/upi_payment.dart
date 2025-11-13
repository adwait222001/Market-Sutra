import 'dart:math';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'homepage.dart'; // ✅ Import your homepage

class Upipayment extends StatefulWidget {
  final String company;
  final String symbol;
  final double amount;
  final String sector;
  final int shares;

  const Upipayment({
    super.key,
    required this.company,
    required this.symbol,
    required this.amount,
    required this.sector,
    required this.shares,
  });

  @override
  State<Upipayment> createState() => _UpipaymentState();
}

class _UpipaymentState extends State<Upipayment> {
  String _enteredPin = "";
  late String _bankNumber;
  bool _hasPrinted = false;

  @override
  void initState() {
    super.initState();
    _bankNumber = _generateRandomBankNumber();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrinted) {
      _hasPrinted = true;
      print("Received Data:");
      print("Company: ${widget.company}");
      print("Symbol: ${widget.symbol}");
      print("Amount: ₹${widget.amount.toStringAsFixed(2)}");
      print("Sector: ${widget.sector}");
      print("Shares: ${widget.shares}");
    }
  }

  String _generateRandomBankNumber() {
    final random = Random();
    return (10000000 + random.nextInt(90000000)).toString();
  }

  void _onKeyPressed(String key) {
    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += key);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<bool> _sendTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    String uid = user?.uid ?? "0"; // ✅ Send "0" if user not logged in

    final url = Uri.parse("YOUR_IP/add_transaction");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "uid": uid,
          "company": widget.company,
          "symbol": widget.symbol,
          "amount": widget.amount,
          "sector": widget.sector,
          "shares": widget.shares,
        }),
      );

      print("✅ Transaction sent to Flask with UID: $uid");
      print("Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Error sending transaction: $e");
      return false;
    }
  }

  void _onTickPressed() async {
    if (_enteredPin.length == 4) {
      bool success = await _sendTransaction();

      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Payment Successful!"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/upi_logo.jpg", width: 80, height: 80),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send transaction. Please try again.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 4-digit PIN')),
      );
    }
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 50,
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade700, width: 2),
            ),
          ),
          child: Text(
            index < _enteredPin.length ? "*" : "",
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        );
      }),
    );
  }

  Widget _buildKey(String key) => Expanded(
    child: GestureDetector(
      onTap: () => _onKeyPressed(key),
      child: Container(
        alignment: Alignment.center,
        height: 65,
        child: Text(
          key,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );

  Widget _buildBackspaceKey() => Expanded(
    child: GestureDetector(
      onTap: _onBackspace,
      child: Container(
        alignment: Alignment.center,
        height: 65,
        child: const Icon(Icons.backspace, size: 28),
      ),
    ),
  );

  Widget _buildTickKey() => Expanded(
    child: GestureDetector(
      onTap: _onTickPressed,
      child: Container(
        alignment: Alignment.center,
        height: 65,
        child: Container(
          width: 65,
          height: 65,
          decoration:
          const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // disables Android back button
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  "Bank-Name: $_bankNumber",
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Image.asset("assets/upi_logo.jpg", width: 60, height: 60),
            ],
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 20),
            Column(
              children: [
                Text(
                  "Amount: ₹${widget.amount.toStringAsFixed(2)}",
                  style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text("ENTER 4 DIGIT UPI PIN",
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 20),
                _buildPinDisplay(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Column(
                children: [
                  Row(children: [_buildKey("1"), _buildKey("2"), _buildKey("3")]),
                  const SizedBox(height: 8),
                  Row(children: [_buildKey("4"), _buildKey("5"), _buildKey("6")]),
                  const SizedBox(height: 8),
                  Row(children: [_buildKey("7"), _buildKey("8"), _buildKey("9")]),
                  const SizedBox(height: 8),
                  Row(children: [_buildBackspaceKey(), _buildKey("0"), _buildTickKey()]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

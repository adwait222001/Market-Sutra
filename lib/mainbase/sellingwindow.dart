import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Sellingwindow extends StatefulWidget {
  final String company;
  final String symbol;
  final String? uid;
  final double? price;

  const Sellingwindow({
    super.key,
    required this.company,
    required this.symbol,
    this.uid,
    this.price,
  });

  @override
  State<Sellingwindow> createState() => _SellingwindowState();
}

class _SellingwindowState extends State<Sellingwindow> {
  final TextEditingController _sharesController = TextEditingController();
  bool loading = true;
  String? error;
  int ownedShares = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserShares();
  }

  Future<void> _fetchUserShares() async {
    final uid = widget.uid ?? "0";
    final url = Uri.parse("YOUR_IP/get_transactions");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          final List transactions = data["transactions"];
          final userTransactions = transactions.where((tx) =>
          tx["uid"] == uid &&
              tx["company"] == widget.company &&
              tx["symbol"] == widget.symbol);

          if (userTransactions.isNotEmpty) {
            final tx = userTransactions.first;
            setState(() {
              ownedShares = tx["shares"] ?? 0;
              loading = false;
            });
          } else {
            setState(() {
              ownedShares = 0;
              loading = false;
            });
          }
        } else {
          setState(() {
            error = "Failed to fetch transactions.";
            loading = false;
          });
        }
      } else {
        setState(() {
          error = "Server error: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error fetching data: $e";
        loading = false;
      });
    }
  }

  void _showConfirmationDialog(int sharesToSell) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Sale"),
          content: Text(
              "Are you sure you want to sell $sharesToSell shares of ${widget.company}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Sold $sharesToSell shares of ${widget.company} (simulation)"),
                  ),
                );
                Navigator.pop(context); // Close Sellingwindow
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sell Shares - ${widget.company}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
            : ownedShares > 0
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Company: ${widget.company}",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("You own $ownedShares shares.",
                style: const TextStyle(fontSize: 16)),
            if (widget.price != null)
              Text("Current Price: ₹${widget.price!.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: _sharesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Enter number of shares to sell",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final sharesToSell = int.tryParse(_sharesController.text) ?? 0;
                      if (sharesToSell <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Enter a valid number.")),
                        );
                      } else if (sharesToSell > ownedShares) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("You don’t own that many shares.")),
                        );
                      } else {
                        _showConfirmationDialog(sharesToSell);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text("Sell Now"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ],
        )
            : const Center(
          child: Text(
            "You don’t own any shares of this company.",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Buyingwindow extends StatelessWidget {
  final String company;
  final String symbol;
  final double price;

  const Buyingwindow({
    super.key,
    required this.company,
    required this.symbol,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController sharesController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    bool isUpdating = false;

    // ---------- Payment Method Dialog ----------
    void showPaymentDialog(BuildContext context) {
      String selectedPaymentMethod = 'Credit-Card/Debit-Card';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Choose Payment Method"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: selectedPaymentMethod,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Credit-Card/Debit-Card',
                          child: Text('Credit-Card/Debit-Card'),
                        ),
                        DropdownMenuItem(
                          value: 'UPI',
                          child: Text('UPI'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedPaymentMethod = value);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close payment dialog
                      Navigator.pop(context); // Close Buyingwindow page
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close payment dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Selected Payment: $selectedPaymentMethod"),
                        ),
                      );
                    },
                    child: const Text("Buy Now"),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    // ---------- Original Buying Dialog ----------
    void shoppingwindow(BuildContext context) {
      showDialog(
        context: context,
        barrierDismissible: false, // Must press Buy or Cancel
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("COMPANY SHARES"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Company Name: $company"),
                  const SizedBox(height: 8),
                  Text("Price per Share: ₹${price.toStringAsFixed(2)}"),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sharesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Number of Shares",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (isUpdating) return;
                      isUpdating = true;
                      double shares = double.tryParse(value) ?? 0;
                      amountController.text =
                          (shares * price).toStringAsFixed(2);
                      isUpdating = false;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    decoration: const InputDecoration(
                      labelText: "Total Amount (₹)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (isUpdating) return;
                      isUpdating = true;
                      double amount = double.tryParse(value) ?? 0;
                      sharesController.text =
                          (amount / price).toStringAsFixed(0);
                      isUpdating = false;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop(); // Close the dialog first
                  Navigator.of(context)
                      .pop(); // Then pop the Buyingwindow page to go back
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close first dialog
                  showPaymentDialog(context); // Open payment dialog
                },
                child: const Text("Buy Now"),
              ),
            ],
          );
        },
      );
    }

    // Show dialog automatically after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      shoppingwindow(context);
    });

    return const Scaffold(
      body: Center(
        child: Text(
          "Buying Window",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

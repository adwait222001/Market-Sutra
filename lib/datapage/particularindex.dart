import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:marketsutra/mainbase/upi_payment.dart';

import '../mainbase/cardpayment.dart';
import '../mainbase/homepage.dart'; // Import UPI page

class particularindex extends StatefulWidget {
  final String indexName;
  final String symbol;

  const particularindex({
    super.key,
    required this.indexName,
    required this.symbol,
  });

  @override
  State<particularindex> createState() => _particularindexState();
}

class _particularindexState extends State<particularindex> {
  // ----- Live price variables -----
  double? price;
  double? previousPrice;
  Color priceColor = Colors.black;
  Icon? priceIcon = const Icon(Icons.remove, color: Colors.black, size: 20);
  String marketStatus = 'Loading...';
  Timer? _priceTimer;

  // ----- Historical prices -----
  List<double> weeklyPrices = [];

  // ----- Server base URL -----
  final String _baseUrl = "YOUR_IP"; // replace with your server IP

  @override
  void initState() {
    super.initState();
    _fetch25WeekPrices();
    _fetchIndexPrice();
    _startPolling();
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  // ----- Polling for live price -----
  void _startPolling() {
    _priceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchIndexPrice();
    });
  }

  Future<void> _fetchIndexPrice() async {
    final url = Uri.parse(
        "$_baseUrl/index-price?name=${Uri.encodeComponent(widget.indexName)}&symbol=${Uri.encodeComponent(widget.symbol)}");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedPrice = data['price'];
        final fetchedStatus = data['market_status'];

        double? newPrice = (fetchedPrice is num) ? fetchedPrice.toDouble() : null;

        if (newPrice != null) {
          if (previousPrice != null) {
            if (newPrice > previousPrice!) {
              priceColor = Colors.green;
              priceIcon = const Icon(Icons.arrow_upward, color: Colors.green, size: 20);
            } else if (newPrice < previousPrice!) {
              priceColor = Colors.red;
              priceIcon = const Icon(Icons.arrow_downward, color: Colors.red, size: 20);
            }
          }
          previousPrice = newPrice;
        }

        setState(() {
          price = newPrice;
          marketStatus = fetchedStatus ?? 'Unknown';
        });
      } else {
        setState(() {
          marketStatus = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        marketStatus = "Error fetching index: $e";
      });
    }
  }

  // ----- Fetch historical 25-week prices -----
  Future<void> _fetch25WeekPrices() async {
    final url = Uri.parse(
      "$_baseUrl/historical_prices?index_name=${Uri.encodeComponent(widget.indexName)}",
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data.containsKey('25_week_prices')) {
        final prices = data['25_week_prices'] as List;
        setState(() {
          weeklyPrices = prices.map((x) => (x as num).toDouble()).toList();
        });
      }
    } catch (e) {
      print("Error fetching historical prices: $e");
    }
  }

  // ---------------- Buying Dialog -----------------
  void _showBuyingDialog() {
    final TextEditingController sharesController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    bool isUpdating = false;

    void showPaymentDialog(BuildContext context, double totalAmount) {
      String selectedPaymentMethod = 'Credit-Card/Debit-Card';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Choose Payment Method"),
                content: DropdownButton<String>(
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
                    if (value != null) setState(() => selectedPaymentMethod = value);
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (selectedPaymentMethod == 'UPI') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Upipayment(
                              company: widget.indexName,
                              symbol: widget.symbol,
                              amount: totalAmount,
                              sector: widget.indexName,
                              //might to look here afterwards
                              shares: int.tryParse(sharesController.text) ?? 0,


                            ),
                          ),
                        );
                      }
                      if (selectedPaymentMethod == 'Credit-Card/Debit-Card') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CardPayment(
                              company: widget.indexName,
                              symbol: widget.symbol,
                              amount: totalAmount,
                              sector: widget.indexName,
                              //might to look here afterwards
                              shares: int.tryParse(sharesController.text) ?? 0,


                            ),
                          ),
                        );
                      }
                      else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Selected Payment: $selectedPaymentMethod"),
                          ),
                        );
                      }
                    },
                    child: const Text("Proceed"),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    void showInvalidAmountDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Invalid Amount"),
            content: Text(
                "Total amount must be at least ₹${price?.toStringAsFixed(2) ?? '0.00'}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("COMPANY SHARES"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Company Name: ${widget.indexName}"),
                    const SizedBox(height: 8),
                    Text("Price per Share: ₹${price?.toStringAsFixed(2) ?? '0.00'}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        "Total Value: ₹${(double.tryParse(amountController.text) ?? 0).toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            (shares * (price ?? 0)).toStringAsFixed(2);
                        setState(() {});
                        isUpdating = false;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
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
                            ((price ?? 1) == 0 ? 0 : (amount / (price ?? 1))).toStringAsFixed(0);
                        setState(() {});
                        isUpdating = false;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    double enteredAmount = double.tryParse(amountController.text) ?? 0;
                    if (enteredAmount < (price ?? 0)) {
                      showInvalidAmountDialog(context);
                    } else {
                      Navigator.pop(context);
                      showPaymentDialog(context, enteredAmount);
                    }
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
  Future<void> checkOwnershipAndShowSellingDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "0";
    int ownedShares = 0;
    double lockedPrice = price ?? 0.0; // ✅ use live price

    _showSellingDialog(context, ownedShares, lockedPrice, isLoading: true);

    try {
      final txUrl = Uri.parse("$_baseUrl/get_transactions");
      final txResponse = await http.get(txUrl);
      if (txResponse.statusCode == 200) {
        final txData = json.decode(txResponse.body);
        final transactions = txData['transactions'] as List<dynamic>;

        final matching = transactions.firstWhere(
              (t) =>
          t['company'] == widget.indexName &&
              t['symbol'] == widget.symbol &&
              t['uid'] == uid,
          orElse: () => null,
        );

        if (matching != null && (matching['shares'] ?? 0) > 0) {
          ownedShares = matching['shares'] as int;
        } else {
          _showErrorDialog(
            context,
            "You do not own any shares of ${widget.indexName} (${widget.symbol}) to sell.",
          );
          return;
        }
      }

      Navigator.of(context, rootNavigator: true).pop();
      _showSellingDialog(context, ownedShares, lockedPrice, isLoading: false);
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog(context, "Something went wrong: $e");
    }
  }

  void _showSellingDialog(BuildContext parentContext, int ownedShares,
      double lockedPrice,
      {bool isLoading = false}) {
    final TextEditingController sharesController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isLoading
                  ? "Loading..."
                  : "SELL INDEX SHARES"),
              content: isLoading
                  ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Index Name: ${widget.indexName}"),
                    const SizedBox(height: 8),
                    Text(
                      "Locked Price per Share: ₹${lockedPrice.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text("Owned Shares: $ownedShares"),
                    const SizedBox(height: 16),
                    TextField(
                      controller: sharesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: "Number of Shares",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (isUpdating) return;
                        isUpdating = true;
                        int shares = int.tryParse(value) ?? 0;
                        if (shares > ownedShares) {
                          shares = ownedShares;
                          sharesController.text = shares.toString();
                        }
                        amountController.text =
                            (shares * lockedPrice).toStringAsFixed(2);
                        setState(() {});
                        isUpdating = false;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Total Amount (₹)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(parentContext, rootNavigator: true).pop(),
                  child: const Text("Cancel"),
                ),
                if (!isLoading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    onPressed: () async {
                      int sharesToSell =
                          int.tryParse(sharesController.text) ?? 0;
                      double totalAmount = sharesToSell * lockedPrice;

                      if (sharesToSell <= 0 || sharesToSell > ownedShares) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                              content:
                              Text("Enter a valid number of shares")),
                        );
                        return;
                      }

                      Navigator.of(parentContext, rootNavigator: true).pop();

                      try {
                        final sellUrl =
                        Uri.parse("$_baseUrl/sell_transaction");
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ?? "0";

                        final response = await http.post(
                          sellUrl,
                          headers: {"Content-Type": "application/json"},
                          body: json.encode({
                            "uid": uid,
                            "company": widget.indexName,
                            "symbol": widget.symbol,
                            "shares": sharesToSell,
                            "price": lockedPrice,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (response.statusCode == 200 &&
                            data["status"] == "success") {
                          showDialog(
                            context: parentContext,
                            barrierDismissible: false,
                            builder: (_) => AlertDialog(
                              title: const Text("Sale Successful"),
                              content: Text(
                                "You sold $sharesToSell shares of ${widget.indexName} "
                                    "at ₹${lockedPrice.toStringAsFixed(2)} per share "
                                    "for ₹${totalAmount.toStringAsFixed(2)}.\n\n${data["message"] ?? ''}",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(parentContext,
                                        rootNavigator: true)
                                        .pop();
                                    Navigator.pushAndRemoveUntil(
                                      parentContext,
                                      MaterialPageRoute(
                                          builder: (_) => const HomePage()),
                                          (route) => false,
                                    );
                                  },
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _showErrorDialog(
                            parentContext,
                            "Failed to sell shares: ${data["message"] ?? 'Unknown error'}",
                          );
                        }
                      } catch (e) {
                        _showErrorDialog(parentContext, "Error: $e");
                      }
                    },
                    child: const Text("Sell Now"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    double minY = 0, maxY = 0, step = 0;
    if (weeklyPrices.isNotEmpty) {
      minY = weeklyPrices.reduce((a, b) => a < b ? a : b);
      maxY = weeklyPrices.reduce((a, b) => a > b ? a : b);
      double range = maxY - minY;
      step = (range / 5).ceilToDouble();
      if (step == 0) step = 1;
      minY = (minY / step).floor() * step;
      maxY = (maxY / step).ceil() * step;
    }

    final now = DateTime.now();
    final marketStatusString = (now.weekday != DateTime.saturday &&
        now.weekday != DateTime.sunday &&
        now.isAfter(DateTime(now.year, now.month, now.day, 9, 15)) &&
        now.isBefore(DateTime(now.year, now.month, now.day, 15, 30)))
        ? 'Open'
        : 'Closed';

    return Scaffold(
      appBar: AppBar(title: Text(widget.indexName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              price != null
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.indexName,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text("Price: ₹",
                          style: TextStyle(fontSize: 20)),
                      Text(
                        price!.toStringAsFixed(2),
                        style: TextStyle(fontSize: 20, color: priceColor),
                      ),
                      const SizedBox(width: 4),
                      if (priceIcon != null)
                        Icon(priceIcon!.icon, color: priceColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text("Market Status: $marketStatusString",
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _showBuyingDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(150, 50),),
                        child: const Text("Buy"),
                      ),

                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: checkOwnershipAndShowSellingDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(150, 50),),
                        child: const Text("Sell "),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  const Divider(thickness: 1, height: 32),
                ],
              )
                  : Row(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(width: 8),
                  Text("Fetching index price...",
                      style: TextStyle(fontSize: 16)),
                ],
              ),
              // ----- 25-week graph -----
              SizedBox(
                height: 250,
                child: weeklyPrices.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: weeklyPrices.length.toDouble() - 1,
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 25,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString(),
                                style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: step,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            String text;
                            if (value >= 1000) {
                              text = "${(value / 1000).toStringAsFixed(1)}K";
                            } else {
                              text = value.toStringAsFixed(0);
                            }
                            return Text(text, style: const TextStyle(fontSize: 12));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          weeklyPrices.length,
                              (index) => FlSpot(index.toDouble(), weeklyPrices[index]),
                        ),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

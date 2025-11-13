import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:marketsutra/mainbase/cardpayment.dart';
import 'package:marketsutra/mainbase/upi_payment.dart';

import '../mainbase/homepage.dart'; // Import UPI page

class Liveshare extends StatefulWidget {
  final String company;
  final String symbol;
  final dynamic type;

  const Liveshare({
    super.key,
    required this.company,
    required this.symbol,
    required this.type,
  });

  @override
  State<Liveshare> createState() => _LiveshareState();
}

class _LiveshareState extends State<Liveshare> {
  double? price;
  double? previousPrice;
  Color priceColor = Colors.black;
  Icon? priceIcon = const Icon(Icons.remove, color: Colors.black, size: 20);
  String marketCap = "N/A";

  Timer? _priceTimer;
  Timer? _peTimer;
  final String _baseUrl = "YOUR_IP";

  Map<String, dynamic>? financeData;
  bool loadingFinance = true;
  String? financeError;

  Map<String, Map<String, String>> _balanceSheetMap = {};
  bool loadingBalanceSheet = true;
  String? balanceSheetError;

  List<Map<String, String>> _weekPrices = [];
  bool loadingWeekPrices = true;
  String? weekPriceError;

  List<FlSpot> priceSpots = [];

  @override
  void initState() {
    super.initState();
    startPolling();
    _fetchFinanceData();
    _fetchBalanceSheet();
    _fetch25WeekPrices();
    _fetchWeekPrices();
    _fetchPERatio();
    _startPEPolling();
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _peTimer?.cancel();
    super.dispose();
  }

  void startPolling() {
    _fetchPrice();
    _priceTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _fetchPrice());
  }

  void _startPEPolling() {
    _peTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _fetchPERatio());
  }

  Future<void> _fetchPERatio() async {
    final url =
    Uri.parse("$_baseUrl/livepe?query=${Uri.encodeComponent(widget.company)}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pe = data['pe_ratio'];
        setState(() {
          financeData ??= {};
          financeData!['stock_info'] ??= {};
          financeData!['stock_info']['pe_ratio'] = pe;
        });
      }
    } catch (e) {
      print("Error fetching P/E ratio: $e");
    }
  }

  Future<void> _fetchWeekPrices() async {
    setState(() {
      loadingWeekPrices = true;
      weekPriceError = null;
    });

    final url = Uri.parse("$_baseUrl/weekprice?symbol=${widget.symbol}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['last_7_days'] as List<dynamic>;
        setState(() {
          _weekPrices = prices.map<Map<String, String>>((e) {
            return {
              'date': e['date'] ?? '',
              'day': e['day'] ?? '',
              'closing_price': e['closing_price']?.toString() ?? '',
            };
          }).toList();
          loadingWeekPrices = false;
        });
      } else {
        setState(() {
          weekPriceError = "Failed to fetch week prices: ${response.statusCode}";
          loadingWeekPrices = false;
        });
      }
    } catch (e) {
      setState(() {
        weekPriceError = "Error fetching week prices: $e";
        loadingWeekPrices = false;
      });
    }
  }

  Future<void> _fetchPrice() async {
    final url =
    Uri.parse("$_baseUrl/price?symbol=${Uri.encodeComponent(widget.symbol)}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final priceStr = data['price']?.toString() ?? '';
        final newPrice = double.tryParse(priceStr);

        final fetchedMarketCap = data['market_cap']?.toString() ?? "N/A";

        if (newPrice != null) {
          if (previousPrice != null) {
            if (newPrice > previousPrice!) {
              priceColor = Colors.green;
              priceIcon =
              const Icon(Icons.arrow_upward, color: Colors.green, size: 20);
            } else if (newPrice < previousPrice!) {
              priceColor = Colors.red;
              priceIcon =
              const Icon(Icons.arrow_downward, color: Colors.red, size: 20);
            }
          }
          previousPrice = newPrice;
          setState(() {
            price = newPrice;
            marketCap = fetchedMarketCap;
          });
        }
      }
    } catch (e) {
      print("Error fetching price: $e");
    }
  }

  Future<void> _fetchFinanceData() async {
    setState(() {
      loadingFinance = true;
      financeError = null;
    });

    final url = Uri.parse(
        "$_baseUrl/finance?company=${Uri.encodeComponent(widget.company)}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          financeData = Map<String, dynamic>.from(data);
          loadingFinance = false;
        });
      } else {
        setState(() {
          financeError =
          "Failed to fetch finance data: ${response.statusCode}";
          loadingFinance = false;
        });
      }
    } catch (e) {
      setState(() {
        financeError = "Error fetching finance data: $e";
        loadingFinance = false;
      });
    }
  }

  Future<void> _fetchBalanceSheet() async {
    setState(() {
      loadingBalanceSheet = true;
      balanceSheetError = null;
    });

    final url = Uri.parse(
        "$_baseUrl/balancesheet?company=${Uri.encodeComponent(widget.company)}&symbol=${widget.symbol}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceData = data['balance_sheet'] as Map<String, dynamic>;
        Map<String, Map<String, String>> parsedData = {};
        for (final entry in balanceData.entries) {
          final year = entry.key;
          final values = Map<String, String>.from(entry.value);
          parsedData[year] = values;
        }
        setState(() {
          _balanceSheetMap = parsedData;
          loadingBalanceSheet = false;
        });
      } else {
        setState(() {
          balanceSheetError =
          "Failed to fetch balance sheet: ${response.statusCode}";
          loadingBalanceSheet = false;
        });
      }
    } catch (e) {
      setState(() {
        balanceSheetError = "Error fetching balance sheet: $e";
        loadingBalanceSheet = false;
      });
    }
  }

  Future<void> _fetch25WeekPrices() async {
    final url = Uri.parse("$_baseUrl/25weekprice?symbol=${widget.symbol}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List<dynamic>;
        setState(() {
          priceSpots = List.generate(prices.length, (index) {
            double val =
                double.tryParse(prices[index]['closing_price'].toString()) ?? 0;
            return FlSpot(index.toDouble(), val);
          });
        });
      }
    } catch (e) {
      print("Error fetching 25-week prices: $e");
    }
  }

  List<DataRow> _buildBalanceSheetRows() {
    final allComponents = <String>{};
    for (var entry in _balanceSheetMap.values) {
      allComponents.addAll(entry.keys);
    }

    final List<String> priority = ['Total Revenue', 'Gross Profit', 'Net Income'];
    final sortedComponents = [
      ...priority,
      ...allComponents.where((key) => !priority.contains(key)).toList()..sort()
    ];

    return sortedComponents.map((component) {
      return DataRow(
        cells: [
          DataCell(Text(component)),
          ..._balanceSheetMap.keys.map((year) {
            final value = _balanceSheetMap[year]?[component];
            return DataCell(Text(value ?? '-'));
          }).toList(),
        ],
      );
    }).toList();
  }

  Widget _buildStockInfo() {
    final stockInfoData = financeData?['stock_info'];

    if (stockInfoData == null || stockInfoData is! Map) {
      return const Text("No stock info available");
    }

    List<Widget> infoWidgets = [];
    stockInfoData.forEach((key, value) {
      if (key == 'description') {
        infoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$key:", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value.toString()),
              ],
            ),
          ),
        );
      } else {
        infoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text("$key: $value"),
          ),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoWidgets,
    );
  }

  Widget _buildGraph() {
    if (priceSpots.isEmpty) return const SizedBox.shrink();

    double minY = priceSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = priceSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    double step = ((maxY - minY) / 5).ceilToDouble();
    minY = (minY / step).floor() * step;
    maxY = (maxY / step).ceil() * step;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            "25 Week Price Graph",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBorderRadius: BorderRadius.circular(8),
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipColor: (touchedSpot) => Colors.blueAccent,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toStringAsFixed(2),
                          const TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: step,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 12));
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: priceSpots,
                    isCurved: true,
                    color: Colors.blue,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
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
                        // ✅ Pass the shares here
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Upipayment(
                              company: widget.company,
                              symbol: widget.symbol,
                              amount: totalAmount,
                              sector: financeData?['stock_info']?['sector'] ?? 'N/A',
                              shares: int.tryParse(sharesController.text) ?? 0,
                            ),
                          ),
                        );
                      }
                      if(selectedPaymentMethod == 'Credit-Card/Debit-Card')
                      {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CardPayment(
                              company: widget.company,
                              symbol: widget.symbol,
                              amount: totalAmount,
                              sector: financeData?['stock_info']?['sector'] ?? 'N/A',
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
                    Text("Company Name: ${widget.company}"),
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

// ---------------- Selling Dialog -----------------
// ---------------- Selling Dialog -----------------
  Future<void> checkOwnershipAndShowSellingDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "0";
    int ownedShares = 0;
    double lockedPrice = 0.0;

    // ✅ Show the dialog immediately (fast UI response)
    _showSellingDialog(context, ownedShares, lockedPrice, isLoading: true);

    try {
      // 🔹 Fetch ownership asynchronously
      final txUrl = Uri.parse("$_baseUrl/get_transactions");
      final txResponse = await http.get(txUrl);
      if (txResponse.statusCode == 200) {
        final txData = json.decode(txResponse.body);
        final transactions = txData['transactions'] as List<dynamic>;

        final matching = transactions.firstWhere(
              (t) =>
          t['company'] == widget.company &&
              t['symbol'] == widget.symbol &&
              t['uid'] == uid,
          orElse: () => null,
        );

        if (matching != null && (matching['shares'] ?? 0) > 0) {
          ownedShares = matching['shares'] as int;
        } else {
          _showErrorDialog(context,
              "You do not own any shares of ${widget.company} (${widget.symbol}) to sell.");
          return;
        }
      }

      // 🔹 Fetch current price asynchronously
      final priceUrl =
      Uri.parse("$_baseUrl/price?symbol=${Uri.encodeComponent(widget.symbol)}");
      final priceResponse = await http.get(priceUrl);
      if (priceResponse.statusCode == 200) {
        final priceData = json.decode(priceResponse.body);
        lockedPrice =
            double.tryParse(priceData['price']?.toString() ?? '') ?? 0.0;
      }

      // ✅ Once both fetched — reopen dialog with updated data
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
                  : "SELL COMPANY SHARES"),
              content: isLoading
                  ? const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Company Name: ${widget.company}"),
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
                    style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      int sharesToSell =
                          int.tryParse(sharesController.text) ?? 0;
                      double totalAmount =
                          sharesToSell * lockedPrice;

                      if (sharesToSell <= 0 || sharesToSell > ownedShares) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                              content: Text("Enter a valid number of shares")),
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
                            "company": widget.company,
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
                                "You sold $sharesToSell shares of ${widget.company} "
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
    final now = DateTime.now();
    final marketStatus = (now.weekday != DateTime.saturday &&
        now.weekday != DateTime.sunday &&
        now.isAfter(DateTime(now.year, now.month, now.day, 9, 15)) &&
        now.isBefore(DateTime(now.year, now.month, now.day, 15, 30)))
        ? 'Open'
        : 'Closed';

    return Scaffold(
      appBar: AppBar(title: Text(widget.company)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (price != null) ...[
                Text(widget.company,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Symbol: ${widget.symbol}",
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Price: ₹", style: TextStyle(fontSize: 18)),
                    Text(price!.toStringAsFixed(2),
                        style: TextStyle(fontSize: 18, color: priceColor)),
                    const SizedBox(width: 4),
                    if (priceIcon != null)
                      Icon(priceIcon!.icon, color: priceColor, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Market Cap: $marketCap", style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  "P/E Ratio: ${financeData?['stock_info']?['pe_ratio'] ?? 'N/A'}",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text("Market Status: $marketStatus",
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),

                // ---------------- Buy & Dummy Sell Button ----------------
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showBuyingDialog,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text("Buy"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          checkOwnershipAndShowSellingDialog();
                        }, // Dummy, does nothing
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text("Sell"),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),
              ] else
                const Center(child: CircularProgressIndicator()),

              _buildGraph(),

              const Text("Company Finance",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              loadingFinance
                  ? const Center(child: CircularProgressIndicator())
                  : financeError != null
                  ? Text(financeError!,
                  style: const TextStyle(color: Colors.red))
                  : ExpansionTile(
                title: const Text(
                  "Stock Information",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                children: [_buildStockInfo()],
              ),

              const SizedBox(height: 16),

              ExpansionTile(
                title: const Text(
                  "Balance Sheet",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                children: [
                  loadingBalanceSheet
                      ? const Center(child: CircularProgressIndicator())
                      : balanceSheetError != null
                      ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(balanceSheetError!,
                        style: const TextStyle(color: Colors.red)),
                  )
                      : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                          Colors.grey[200]),
                      columns: [
                        const DataColumn(label: Text("Component")),
                        ..._balanceSheetMap.keys
                            .map((year) => DataColumn(label: Text(year)))
                            .toList(),
                      ],
                      rows: _buildBalanceSheetRows(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              ExpansionTile(
                title: const Text(
                  "Last 7 Trading Days Prices",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                children: [
                  loadingWeekPrices
                      ? const Center(child: CircularProgressIndicator())
                      : weekPriceError != null
                      ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(weekPriceError!,
                        style: const TextStyle(color: Colors.red)),
                  )
                      : Column(
                    children: _weekPrices.map((price) {
                      return ListTile(
                        title: Text("${price['day']} - ${price['date']}"),
                        trailing: Text(price['closing_price'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

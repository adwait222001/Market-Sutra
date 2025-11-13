import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class portfolio extends StatefulWidget {
  final String baseUrl;
  const portfolio({Key? key, required this.baseUrl}) : super(key: key);

  @override
  State<portfolio> createState() => _portfolioState();
}

class _portfolioState extends State<portfolio> {
  bool _isLoading = true;
  List<Holding> _holdings = [];
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    try {
      final txUrl = Uri.parse("${widget.baseUrl}/get_transactions");
      final txResponse = await http.get(txUrl);
      if (txResponse.statusCode != 200) throw "Failed to fetch transactions";

      final data = json.decode(txResponse.body);
      final txList = List<Map<String, dynamic>>.from(data['transactions']);
      final List<Holding> temp = [];

      // Add all holdings with shares > 0
      for (var tx in txList) {
        final h = Holding.fromJson(tx);
        if (h.shares > 0) temp.add(h);
      }

      // Fetch all prices concurrently
      await Future.wait(temp.map((h) async {
        final price = await _fetchPriceForHolding(h);
        h.currentPrice = price;
        h.totalValue = h.currentPrice * h.shares;
      }));

      if (mounted) {
        setState(() {
          _holdings = temp;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading portfolio: $e")),
        );
      }
    }
  }

  Future<double> _fetchPriceForHolding(Holding h) async {
    try {
      final s = h.symbol.toUpperCase();
      Uri url;
      if (s.contains("INDEXNSE") || s.contains("INDEXBSE")) {
        final encodedName = Uri.encodeComponent(h.company);
        final encodedSymbol = Uri.encodeComponent(h.symbol);
        url = Uri.parse(
            "${widget.baseUrl}/index-price?name=$encodedName&symbol=$encodedSymbol");
      } else {
        final encodedSymbol = Uri.encodeComponent(h.symbol);
        url = Uri.parse("${widget.baseUrl}/price?symbol=$encodedSymbol");
      }

      final res = await http.get(url);
      if (res.statusCode != 200) return 0.0;
      final jsonData = json.decode(res.body);
      return double.tryParse(jsonData['price'].toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  double get _totalValue =>
      _holdings.fold(0, (sum, h) => sum + (h.totalValue));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Portfolio")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _holdings.isEmpty
          ? const Center(child: Text("No holdings found"))
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // PIE + LEGEND
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PIE CHART
                  Expanded(
                    flex: 2,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 0, end: _touchedIndex != null ? 1 : 0),
                        duration: const Duration(milliseconds: 350),
                        builder: (context, anim, _) {
                          return PieChart(
                            PieChartData(
                              sections: _buildSections(anim),
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  if (!event
                                      .isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null)
                                    return;
                                  setState(() {
                                    _touchedIndex = response
                                        .touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                              ),
                              sectionsSpace: 2,
                              centerSpaceRadius: 0,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // LEGEND
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                        List.generate(_holdings.length, (i) {
                          final h = _holdings[i];
                          final color = _colorForIndex(i);
                          final selected = _touchedIndex == i;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _touchedIndex = i);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(6),
                                color: selected
                                    ? color.withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    color: color,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      h.company,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // TOTAL VALUE BELOW PIE
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                "Total Portfolio Value: ₹${_totalValue.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _touchedIndex != null
          ? _buildDetailCard(_holdings[_touchedIndex!])
          : null,
    );
  }

  /// 🔹 Pop-out Slice Logic with Shrinking Others
  List<PieChartSectionData> _buildSections(double anim) {
    final total = _totalValue == 0 ? 1 : _totalValue;

    return List.generate(_holdings.length, (i) {
      final h = _holdings[i];
      final isSelected = i == _touchedIndex;

      // make selected slice large, others smaller
      final baseRadius = 60.0;
      final selectedRadius = baseRadius + (30 * anim); // pop-out more
      final otherRadius = baseRadius - (10 * anim); // shrink others

      final radius = isSelected ? selectedRadius : otherRadius;
      final value = (h.totalValue / total) * 100;

      return PieChartSectionData(
        color: _colorForIndex(i),
        value: value,
        radius: radius,
        title: "",
      );
    });
  }

  Color _colorForIndex(int index) {
    const base = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.brown,
    ];
    return base[index % base.length];
  }

  Widget _buildDetailCard(Holding h) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            h.company,
            style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text("Sector: ${h.sector}"),
          Text("Symbol: ${h.symbol}"),
          Text("Shares: ${h.shares}"),
          Text("Price: ₹${h.currentPrice.toStringAsFixed(2)}"),
          Text(
            "Value: ₹${h.totalValue.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class Holding {
  final String company;
  final String symbol;
  final String sector;
  final int shares;
  double currentPrice;
  double totalValue;

  Holding({
    required this.company,
    required this.symbol,
    required this.sector,
    required this.shares,
    this.currentPrice = 0,
    this.totalValue = 0,
  });

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
    company: j['company'] ?? '',
    symbol: j['symbol'] ?? '',
    sector: j['sector'] ?? '',
    shares: int.tryParse(j['shares'].toString()) ?? 0,
  );
}

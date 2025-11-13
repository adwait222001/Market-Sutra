import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class IndexPage extends StatefulWidget {
  final String apiUrl;
  final double scrollSpeed;

  const IndexPage({
    required this.apiUrl,
    this.scrollSpeed = 40,
    super.key,
  });

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  List<Map<String, dynamic>> indexData = [];
  String marketStatus = 'Loading...';
  final ScrollController indexScroll = ScrollController();
  final ScrollController statusScroll = ScrollController();
  bool isLoading = true;

  Timer? indexTimer;
  Timer? statusTimer;
  Timer? fetchTimer;

  Map<String, Color> indexColors = {};
  Map<String, double> previousPrices = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchData();
      fetchTimer = Timer.periodic(
        const Duration(seconds: 5),
            (_) => fetchData(),
      );
    });
  }

  @override
  void dispose() {
    fetchTimer?.cancel();
    indexTimer?.cancel();
    statusTimer?.cancel();
    indexScroll.dispose();
    statusScroll.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse(widget.apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        setState(() {
          marketStatus = data['status']?.toString() ?? "Status unavailable";

          // Handle index/prices data
          if (data.containsKey('indices') && data['indices'] is List) {
            indexData = (data['indices'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (data.containsKey('prices') && data['prices'] is Map) {
            final prices = data['prices'] as Map<String, dynamic>;
            indexData = prices.entries.map((e) {
              final value = Map<String, dynamic>.from(e.value);
              return {
                "name": e.key,
                "price": value["price"] ?? "",
                "difference": value["difference"] ?? "",
                "direction": value["direction"] ?? "",
              };
            }).toList();
          } else {
            indexData = [];
          }

          isLoading = false;

          // Update colors based on price changes
          for (var item in indexData) {
            final name = item['name']?.toString() ?? '';
            final rawPrice = item['price'];
            double price = 0;

            if (rawPrice is num) {
              price = rawPrice.toDouble();
            } else if (rawPrice is String) {
              price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0;
            }

            if (previousPrices.containsKey(name)) {
              if (price > previousPrices[name]!) {
                indexColors[name] = Colors.green;
              } else if (price < previousPrices[name]!) {
                indexColors[name] = Colors.red;
              } else {
                indexColors[name] = Colors.black;
              }
            } else {
              indexColors[name] = Colors.black;
            }

            previousPrices[name] = price;
          }
        });

        // Start auto-scroll timers if not already started
        if (indexTimer == null && statusTimer == null) startAutoScroll();
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    }
  }

  void startAutoScroll() {
    indexTimer = Timer.periodic(
      Duration(milliseconds: widget.scrollSpeed.toInt()),
          (_) {
        if (!indexScroll.hasClients) return;
        final maxScroll = indexScroll.position.maxScrollExtent;
        final next = indexScroll.offset + 1;
        indexScroll.jumpTo(next >= maxScroll ? 0 : next);
      },
    );

    statusTimer = Timer.periodic(
      Duration(milliseconds: widget.scrollSpeed.toInt()),
          (_) {
        if (!statusScroll.hasClients) return;
        final maxScroll = statusScroll.position.maxScrollExtent;
        final next = statusScroll.offset + 1;
        statusScroll.jumpTo(next >= maxScroll ? 0 : next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(color: Colors.purple),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Market status ticker
        SizedBox(
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: statusScroll,
            child: Row(
              children: List.generate(
                20,
                    (index) => TickerCard(
                  text: marketStatus,
                  color: index % 2 == 0 ? Colors.red : Colors.green,
                  size: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Index ticker
        SizedBox(
          height: 60,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: indexScroll,
            child: Row(
              children: indexData.map((item) {
                final name = item['name']?.toString() ?? '';
                final price = item['price']?.toString() ?? '';
                final diff = item['difference']?.toString() ?? '';
                final dir = item['direction']?.toString() ?? '';
                final color = indexColors[name]?.withOpacity(0.2) ?? Colors.black;

                return TickerCard(
                  text: "$name: ₹$price, $diff $dir",
                  color: color,
                  size: 13,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class TickerCard extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const TickerCard({
    required this.text,
    this.color = Colors.deepPurple,
    this.size = 13,
    this.margin,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 6),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
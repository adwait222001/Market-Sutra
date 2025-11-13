import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class IndexGraphCard extends StatefulWidget {
  final String baseUrl;
  final void Function(
      Map<String, List<double>> group2,
      Map<String, List<double>> group3,
      Map<String, List<double>> group4)? onDataReady;

  const IndexGraphCard({
    super.key,
    this.baseUrl = "YOUR_IP",
    this.onDataReady,
  });

  @override
  State<IndexGraphCard> createState() => _IndexGraphCardState();
}

class _IndexGraphCardState extends State<IndexGraphCard> {
  Timer? _refreshTimer;

  Map<String, List<double>> group2 = {};
  Map<String, List<double>> group3 = {};
  Map<String, List<double>> group4 = {};

  bool loading = true;
  String? error;
  bool showingCache = false;

  late final String _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = widget.baseUrl;
    _loadCachedData(); // ✅ Try loading cached data first
    _fetchAllGroups(); // ✅ Fetch from API
    _startPolling();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchAllGroups(silent: true);
    });
  }

  /// ✅ Load cached graph data
  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString("cached_index_groups");
    if (cached != null) {
      try {
        final data = json.decode(cached) as Map<String, dynamic>;
        setState(() {
          group2 = _parseGroupData(data['group_2']);
          group3 = _parseGroupData(data['group_3']);
          group4 = _parseGroupData(data['group_4']);
          loading = false;
          showingCache = true;
        });
      } catch (e) {
        print("Error decoding cached graph data: $e");
      }
    }
  }

  /// ✅ Fetch from API and cache it
  Future<void> _fetchAllGroups({bool silent = false}) async {
    if (!silent && group2.isEmpty && group3.isEmpty && group4.isEmpty) {
      setState(() => loading = true);
    }

    try {
      final url = Uri.parse("$_baseUrl/four-group");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        Map<String, List<double>> rawGroup2 = _parseGroupData(data['group_2']);
        Map<String, List<double>> rawGroup3 = _parseGroupData(data['group_3']);
        Map<String, List<double>> rawGroup4 = _parseGroupData(data['group_4']);

        group2 = {};
        rawGroup2.forEach((key, value) {
          String normalizedKey =
          key.replaceAll(RegExp(r'[_\s]'), '').toUpperCase();
          if (normalizedKey == 'NIFTY50') group2['NIFTY_50'] = value;
        });
        if (rawGroup2.isNotEmpty) {
          String lastKey = rawGroup2.keys.last;
          String normalizedLast =
          lastKey.replaceAll(RegExp(r'[_\s]'), '').toUpperCase();
          if (normalizedLast != 'NIFTY50') group2[lastKey] = rawGroup2[lastKey]!;
        }

        group3 = rawGroup3;
        group4 = rawGroup4;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("cached_index_groups", json.encode(data));

        setState(() {
          loading = false;
          error = null;
          showingCache = false;
        });

        if (!silent && widget.onDataReady != null && group2.isNotEmpty) {
          widget.onDataReady!(group2, group3, group4);
        }
      } else {
        _loadCacheOnFailure("Failed to fetch data: ${response.statusCode}");
      }
    } catch (e) {
      _loadCacheOnFailure("Error fetching data: $e");
    }
  }

  /// ✅ Fallback to cached data
  Future<void> _loadCacheOnFailure(String errorMsg) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString("cached_index_groups");
    if (cached != null) {
      try {
        final data = json.decode(cached) as Map<String, dynamic>;
        setState(() {
          group2 = _parseGroupData(data['group_2']);
          group3 = _parseGroupData(data['group_3']);
          group4 = _parseGroupData(data['group_4']);
          showingCache = true;
          error = "⚠️ Showing cached data (Offline)";
          loading = false;
        });
      } catch (e) {
        setState(() {
          error = "Error reading cached data";
          loading = false;
        });
      }
    } else {
      setState(() {
        error = errorMsg;
        loading = false;
      });
    }
  }

  Map<String, List<double>> _parseGroupData(dynamic groupData) {
    Map<String, List<double>> parsed = {};
    if (groupData is Map<String, dynamic>) {
      groupData.forEach((key, value) {
        if (value is List) {
          parsed[key] = value.map((x) => (x as num).toDouble()).toList();
        }
      });
    }
    return parsed;
  }

  Widget _buildGraphCard(String indexName, List<double> prices) {
    if (prices.isEmpty) return const SizedBox.shrink();

    double minY = prices.reduce((a, b) => a < b ? a : b);
    double maxY = prices.reduce((a, b) => a > b ? a : b);
    double step = ((maxY - minY) / 5).ceilToDouble();
    if (step == 0) step = 1;
    minY = (minY / step).floor() * step;
    maxY = (maxY / step).ceil() * step;

    return SizedBox(
      width: 310,
      height: 320,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$indexName - Current: ₹${prices.last.toStringAsFixed(2)}",
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: prices.length.toDouble() - 1,
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: step,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            String text;
                            double displayValue = value;
                            if (value >= 1000) {
                              displayValue = value / 1000;
                              text = "${displayValue.toStringAsFixed(1)}K";
                            } else {
                              text = value.toStringAsFixed(0);
                            }
                            bool hasDecimal = text.contains('.');
                            return Text(
                              text,
                              style: TextStyle(fontSize: hasDecimal ? 10 : 12),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          prices.length,
                              (index) =>
                              FlSpot(index.toDouble(), prices[index]),
                        ),
                        isCurved: true,
                        color: showingCache ? Colors.grey : Colors.blue,
                        barWidth: 2,
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

  @override
  Widget build(BuildContext context) {
    if (loading && group2.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && group2.isEmpty) {
      return Center(
        child: Text(
          error!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    List<Widget> graphCards = [];
    group2.forEach((key, value) => graphCards.add(_buildGraphCard(key, value)));
    group3.forEach((key, value) => graphCards.add(_buildGraphCard(key, value)));
    group4.forEach((key, value) => graphCards.add(_buildGraphCard(key, value)));

    return Column(
      children: [
        if (error != null && group2.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: graphCards,
          ),
        ),
      ],
    );
  }
}

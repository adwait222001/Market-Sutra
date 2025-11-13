import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class commonnews extends StatefulWidget {
  const commonnews({super.key});

  @override
  State<commonnews> createState() => _commonnewsState();
}

class _commonnewsState extends State<commonnews> {
  List<dynamic> _newsList = [];
  bool _isLoading = true;
  String? _error;

  final String apiUrl = "YOUR_IP/news";

  @override
  void initState() {
    super.initState();
    _loadCachedNews(); // ✅ Show cached news first
    _fetchNews(); // ✅ Then fetch new data
  }

  /// ✅ Load cached news
  Future<void> _loadCachedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_news');
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = json.decode(cachedData);
        if (mounted) {
          setState(() {
            _newsList = decoded;
            _isLoading = false;
          });
        }
      } catch (e) {
        print("Error decoding cached news: $e");
      }
    }
  }

  /// ✅ Fetch news and cache it
  Future<void> _fetchNews({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          final List<dynamic> newsData = data['data'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_news', json.encode(newsData));

          setState(() {
            _newsList = newsData;
            _isLoading = false;
          });
        } else {
          _loadCacheOnFailure("Failed to fetch news");
        }
      } else {
        _loadCacheOnFailure("Error: ${response.statusCode}");
      }
    } catch (e) {
      _loadCacheOnFailure("Error fetching news: $e");
    }
  }

  /// ✅ Use cache if network fails
  Future<void> _loadCacheOnFailure(String errorMsg) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_news');
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = json.decode(cachedData);
        if (mounted) {
          setState(() {
            _newsList = decoded;
            _error = "⚠️ Showing cached news (Offline mode)";
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = "Error reading cached news";
            _isLoading = false;
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _error = errorMsg;
        _isLoading = false;
      });
    }
  }

  /// ✅ Open article in browser
  Future<void> _launchURL(String url) async {
    if (!url.startsWith('http')) url = 'https://$url';
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $url')),
        );
      }
    }
  }

  /// ✅ Build image safely
  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == "No Image") {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 40, color: Colors.grey),
      );
    }
    return Image.network(
      imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
        width: 80,
        height: 80,
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorBuilder: (context, error, stackTrace) => Container(
        width: 80,
        height: 80,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  /// ✅ Single news card
  Widget _buildNewsCard(dynamic newsItem) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _buildImage(newsItem['image']),
        title: Text(
          newsItem['title'] ?? 'No Title',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        onTap: () {
          if (newsItem['link'] != null && newsItem['link'] != "") {
            _launchURL(newsItem['link']);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No link available')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _newsList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _newsList.isEmpty) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchNews(silent: true),
      child: ListView.builder(
        shrinkWrap: true, // ✅ Make list fit content
        physics: const NeverScrollableScrollPhysics(), // ✅ Disable inner scrolling
        itemCount: _newsList.length,
        itemBuilder: (context, index) => _buildNewsCard(_newsList[index]),
      ),
    );
  }
}

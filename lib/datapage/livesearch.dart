import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'liveshare.dart';
import 'particularindex.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, String>> _suggestions = [];
  String? _error;
  final String _baseUrl = "YOUR_IP";
  String _searchType = "share";

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _searchController.text.trim().isNotEmpty) {
        _showOverlay();
        _fetchSuggestions(_searchController.text.trim());
      } else {
        _removeOverlay();
      }
    });

    _searchController.addListener(() {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _fetchSuggestions(query);
      } else {
        _removeOverlay();
        setState(() => _suggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlay();
    Overlay.of(context, rootOverlay: true)?.insert(_overlayEntry!);
  }

  OverlayEntry _createOverlay() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Full-screen transparent layer to catch outside taps
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _focusNode.unfocus();
                _removeOverlay(); // Collapse dropdown immediately
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // Dropdown positioned under search box
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height,
            width: size.width,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: _suggestions.isEmpty
                    ? _error != null
                    ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                    : const SizedBox()
                    : ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(_searchType == "share"
                          ? "${suggestion['company']}"
                          : "${suggestion['index']}"),
                      subtitle: Text("Symbol: ${suggestion['symbol']}"),
                      onTap: () async {
                        _focusNode.unfocus();
                        _removeOverlay();
                        if (_searchType == "share") {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Liveshare(
                                company: suggestion['company']!,
                                symbol: suggestion['symbol']!,
                                type: _searchType,
                              ),
                            ),
                          );
                        } else {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => particularindex(
                                indexName: suggestion['index']!,
                                symbol: suggestion['symbol']!,
                              ),
                            ),
                          );
                        }
                        _searchController.clear();
                        setState(() => _suggestions = []);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;
    final endpoint = _searchType == "share" ? "match" : "match_index";
    final url = Uri.parse("$_baseUrl/$endpoint?query=${Uri.encodeComponent(query)}");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final matchesMap = data['matches'] as Map<String, dynamic>?;

        if (matchesMap != null) {
          final suggestionList = matchesMap.entries.map<Map<String, String>>((entry) {
            final value = entry.value as Map<String, dynamic>;
            return {
              _searchType == "share" ? 'company' : 'index':
              value[_searchType == "share" ? 'company' : 'index']?.toString() ?? '',
              'symbol': value['symbol']?.toString() ?? '',
            };
          }).toList();

          setState(() {
            _suggestions = suggestionList;
            _error = null;
          });
          if (_focusNode.hasFocus) _showOverlay();
        } else {
          setState(() {
            _suggestions = [];
            _error = "No matches found.";
          });
          if (_focusNode.hasFocus) _showOverlay();
        }
      } else {
        setState(() {
          _error = "Server error: ${response.statusCode}";
        });
        if (_focusNode.hasFocus) _showOverlay();
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
      if (_focusNode.hasFocus) _showOverlay();
    }
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _searchType = "share";
                _fetchSuggestions(_searchController.text.trim());
              });
            },
            child: Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                color: _searchType == "share" ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                "Share",
                style: TextStyle(
                  color: _searchType == "share" ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _searchType = "index";
                _fetchSuggestions(_searchController.text.trim());
              });
            },
            child: Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                color: _searchType == "index" ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                "Index",
                style: TextStyle(
                  color: _searchType == "index" ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double searchWidth = screenWidth * 0.75;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: searchWidth,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: _searchType == "share" ? 'Search shares...' : 'Search indexes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _removeOverlay();
                    setState(() => _suggestions = []);
                  },
                )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              ),
            ),
          ),
          if (_focusNode.hasFocus) _buildTypeSelector(),
        ],
      ),
    );
  }
}

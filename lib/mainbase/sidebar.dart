import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marketsutra/mainbase/portfolio.dart';
import 'package:marketsutra/auth-process/startpage.dart'; // ✅ Import Start page

class sidebar extends StatefulWidget {
  const sidebar({super.key});

  @override
  State<sidebar> createState() => _sidebarState();
}

class _sidebarState extends State<sidebar> {
  String? _userId;
  String? _imageUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      await _fetchProfileImage();
    } else {
      setState(() {
        _userId = null;
        _imageUrl = null;
      });
    }
  }

  // Fetch profile image from Flask
  Future<void> _fetchProfileImage() async {
    if (_userId == null) return;

    final url = Uri.parse('YOUR_IP/uploads/$_userId.jpg');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _imageUrl = url.toString();
        });
      } else {
        setState(() {
          _imageUrl = null;
        });
      }
    } catch (error) {
      setState(() {
        _imageUrl = null;
      });
    }
  }

  // Fetch username from Flask
  Future<String> _getUserName(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    String value;

    if (user == null) {
      value = "User not authenticated";
      return value;
    }

    String userId = user.uid;

    try {
      final response = await http.get(
        Uri.parse('YOUR_IP/name?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        String userName = responseData['name'];
        value = userName;
        return value;
      } else {
        final responseData = json.decode(response.body);
        return responseData['message'] ?? 'Failed to fetch username';
      }
    } catch (e) {
      return 'Error occurred: $e';
    }
  }

  // ✅ Sign out function
  Future<void> _signOut(BuildContext context) async {
    try {
      await _auth.signOut();

      // After sign out, navigate to Start page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Start()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("Error during sign out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign out failed: ${e.message}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          FutureBuilder<String>(
            future: _getUserName(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const UserAccountsDrawerHeader(
                  accountName: Text("Loading..."),
                  accountEmail: null,
                );
              } else if (snapshot.hasError) {
                return const UserAccountsDrawerHeader(
                  accountName: Text("Error"),
                  accountEmail: null,
                  currentAccountPicture: ClipOval(
                    child: Icon(Icons.person, size: 40),
                  ),
                );
              } else {
                return UserAccountsDrawerHeader(
                  accountName: Text(
                    snapshot.data ?? "Anonymous User",
                    style: const TextStyle(fontSize: 14),
                  ),
                  accountEmail: null,
                  currentAccountPicture: ClipOval(
                    child: _imageUrl != null
                        ? Image.network(
                      _imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                        : const Icon(Icons.person, size: 40),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 40),

          // ✅ Sign out button
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text("Sign out"),
            onTap: () => _signOut(context),
          ),

          const SizedBox(height: 40),

          ListTile(
            leading: Image.asset(
              'assets/icons/portfolio.png',
              width: 50,
              height: 50,
            ),
            title: const Text("Portfolio"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const portfolio(
                    baseUrl: 'YOUR_IP',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

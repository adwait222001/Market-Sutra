import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'pan.dart';
import '../mainbase/homepage.dart';
import '../mainbase/nointernet.dart';
// page for incomplete data

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool visible = true;
  bool isSignInMode = true;
  User? user;

  String formatEmail(String input) {
    if (!input.contains('@')) return '$input@gmail.com';
    return input;
  }

  // ---------------- ALERT DIALOG FUNCTION ----------------
  Future<void> showAlertDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // ---------------- SERVER CHECK ----------------
  Future<void> checkServerAndNavigate(User firebaseUser) async {
    try {
      String uid = firebaseUser.uid;
      var url = Uri.parse('YOUR_IP/check');
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"uid": uid}),
      );

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Panimage()),
        );
      }
    } catch (e) {
      print("Error checking server: $e");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NoInternetScreen()),
      );
    }
  }

  // ---------------- SIGN IN ----------------
  Future<void> signin() async {
    try {
      String userEmail = formatEmail(email.text.trim());
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
          email: userEmail, password: password.text.trim());
      user = credential.user;

      await showAlertDialog("Success", "Sign-in successful");

      if (user != null) {
        await checkServerAndNavigate(user!);
      }
    } on FirebaseAuthException catch (e) {
      await showAlertDialog("Sign-in Failed", e.message ?? "Sign-in failed");
    }
  }

  // ---------------- REGISTER ----------------
  Future<void> register() async {
    try {
      String userEmail = formatEmail(email.text.trim());
      UserCredential credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: userEmail, password: password.text.trim());
      user = credential.user;

      await showAlertDialog("Success", "Registration successful");

      if (user != null) {
        await checkServerAndNavigate(user!);
      }
    } on FirebaseAuthException catch (e) {
      await showAlertDialog(
          "Registration Failed", e.message ?? "Registration failed");
    }
  }

  // ---------------- GOOGLE SIGN-IN ----------------
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        user = userCredential.user;
      });

      await showAlertDialog(
          "Google Sign-In", "Signed in as ${user!.displayName}");

      if (user != null) {
        await checkServerAndNavigate(user!);
      }
    } catch (e) {
      await showAlertDialog("Google Sign-In Failed", e.toString());
    }
  }

  // ---------------- APPLE SIGN-IN ----------------
  Future<void> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      setState(() {
        user = userCredential.user;
      });

      await showAlertDialog(
          "Apple Sign-In",
          "Signed in as ${user!.displayName ?? 'Apple User'}");

      if (user != null) {
        await checkServerAndNavigate(user!);
      }
    } catch (e) {
      await showAlertDialog("Apple Sign-In Failed", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/icons/wallpaper.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: visible
                ? Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            visible = false;
                            isSignInMode = false;
                          });
                        },
                        child: const Text(
                          "Register",
                          style: TextStyle(
                              fontSize: 30, color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 90),
                      const Text(
                        "ALREADY HAVE AN ACCOUNT?",
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            visible = false;
                            isSignInMode = true;
                          });
                        },
                        child: const Text(
                          "Sign-in",
                          style: TextStyle(
                              fontSize: 30, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isSignInMode
                                ? "Sign in to your account"
                                : "Register a new account",
                            style: TextStyle(
                              fontSize: 24,
                              color: isSignInMode
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 30),
                          TextField(
                            controller: email,
                            style:
                            const TextStyle(color: Colors.green),
                            decoration: const InputDecoration(
                                labelText: 'Email address'),
                          ),
                          const SizedBox(height: 30),
                          TextField(
                            controller: password,
                            style: const TextStyle(color: Colors.red),
                            decoration: const InputDecoration(
                                labelText: 'Password'),
                            obscureText: true,
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isSignInMode = !isSignInMode;
                              });
                            },
                            child: Text(
                              isSignInMode
                                  ? "Don't have an account? Register"
                                  : "Already have an account? Sign-in",
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              if (isSignInMode) {
                                signin();
                              } else {
                                register();
                              }
                            },
                            child: Text(isSignInMode
                                ? "Sign-in"
                                : "Register"),
                          ),
                          const SizedBox(height: 10),
                          const Text("or",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.amberAccent)),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: signInWithGoogle,
                            icon: Image.asset(
                              'assets/google_light.png',
                              height: 30,
                              width: 30,
                            ),
                            label:
                            const Text("Continue with Google"),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: signInWithApple,
                            icon: const Icon(Icons.apple,
                                color: Colors.black),
                            label:
                            const Text("Continue with Apple"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

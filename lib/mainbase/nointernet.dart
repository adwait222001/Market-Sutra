import 'package:flutter/material.dart';
import 'package:marketsutra/auth-process/startpage.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purpleAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => Start()),
                );
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marketsutra/mainbase/homepage.dart';


class Details extends StatefulWidget {
  const Details({super.key});

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> with SingleTickerProviderStateMixin {
  Color bgColor = Colors.white;

  late AnimationController _controller;
  double circleSize = 0;
  Offset circleOrigin = Offset.zero;
  Color disperseColor = Colors.transparent;

  int? clickedIndex;

  final List<Color> colors = [
    Colors.green, // Bull
    Colors.blue,  // Whale
    Colors.purple, // Deer
    Colors.grey,  // Turtle
    Colors.red,   // Bear
  ];

  final List<String> animalNames = [
    'Bull',
    'Whale',
    'Deer',
    'Turtle',
    'Bear',
  ];

  // Info text for each animal
  final List<String> animalInfoTexts = [
    "A bull is one of the most famous and positive animals on the market. The market is in positive territory, with stock and investors placing more money into the market. If the market is bullish, investors are confident about the market, which increases the price of stocks.", // Bull
    "Whales are investors, usually unidentified, who make an unusually large amount of money in the market for stocks. Whale orders can alter the direction of the stock and have an impact on market fluctuations as well.", // Whale
    "Stags are short-term spectators. They buy and sell stocks very quickly, usually within just a few hours of the day. Stags (also known as a male deer) need a lot of cash on hand in order to play the market this quickly. They depend on taking advantage of small price movements.", // Deer
    "A turtle refers to investors in the stock market who invest for a longer period of time. One makes the fewest number of trades and doesn’t focus on short term gains or losses.", // Turtle
    "The bear market happens to be exactly the opposite of a bull market. The outlook and attitude of investors towards the market are negative and pessimistic in a bear market, resulting in lower investment. The market is considered to be in a bearish mood when there is a drop of around.", // Bear
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _controller.addListener(() {
      setState(() {
        circleSize = _controller.value * 500;
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          bgColor = clickedIndex != null ? colors[clickedIndex!] : bgColor;
        });
      }
    });

    // Show initial dialog on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Welcome!"),
          content: const Text(
              "Please choose what type of investing person you are."),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void onOptionTap(int index, Offset buttonPosition) {
    setState(() {
      circleOrigin = buttonPosition;
      disperseColor = colors[index];
      clickedIndex = index;
      animal(animalType: animalNames[index]);
    });
    _controller.forward(from: 0);
  }

  String getAssetPath(int index) {
    switch (index) {
      case 0:
        return 'assets/icons/bull.png';
      case 1:
        return 'assets/icons/whale.png';
      case 2:
        return 'assets/icons/dear.jpg';
      case 3:
        return 'assets/icons/turtle.jpg';
      case 4:
        return 'assets/icons/bear.jpeg';
      default:
        return '';
    }
  }

  Widget buildButton(int index, double buttonRadius, Offset buttonOffset) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Animal button
        Positioned(
          left: buttonOffset.dx - buttonRadius,
          top: buttonOffset.dy - buttonRadius,
          child: GestureDetector(
            onTap: () {
              final renderBox = context.findRenderObject() as RenderBox;
              final globalOffset = renderBox.localToGlobal(buttonOffset);
              onOptionTap(index, globalOffset);
            },
            child: Container(
              width: buttonRadius * 2,
              height: buttonRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[index],
              ),
              child: ClipOval(
                child: Image.asset(
                  getAssetPath(index),
                  width: buttonRadius * 2,
                  height: buttonRadius * 2,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        // Info "i" button with scrollable, padded text
        Positioned(
          left: buttonOffset.dx + buttonRadius - 20,
          top: buttonOffset.dy - buttonRadius - 20,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  content: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        animalInfoTexts[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"))
                  ],
                ),
              );
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.black),
              ),
              child: const Center(
                child: Text(
                  'i',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFullWheelImage(double wheelSize) {
    if (clickedIndex == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      top: 0,
      child: SizedBox(
        width: wheelSize,
        height: wheelSize,
        child: ClipOval(
          child: Image.asset(
            getAssetPath(clickedIndex!),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Future<void> animal({required String animalType}) async {
    final user = FirebaseAuth.instance.currentUser!;
    String userID = user.uid;
    final response = await http.post(
      Uri.parse('YOUR_IP/animal'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'animal_type': animalType,
        'user_id': userID,
      }),
    );
    if (response.statusCode == 200) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: SizedBox(
            height: 50,
            child: Center(
              child: Text(
                  "Congrats $animalType! Hope you have the best time with us"),
            ),
          ),
          actions: [
            ElevatedButton(
                onPressed: (){Navigator.push(context,MaterialPageRoute(builder: (context)=>HomePage()));},
                child: const Text("OK"))
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: SizedBox(
            height: 50,
            child: Center(
              child: Text("There was a problem, please retry"),
            ),
          ),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final wheelSize = min(screenSize.width, screenSize.height) * 0.7;
    final mainCircleRadius = wheelSize / 2;

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: bgColor,
            child: const SizedBox.expand(),
          ),

          // Back button with dynamic color
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 30),
              color: clickedIndex != null ? colors[clickedIndex!] : Colors.black,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // Spread animation
          Positioned(
            left: circleOrigin.dx - circleSize / 2,
            top: circleOrigin.dy - circleSize / 2,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: disperseColor.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main wheel
          Center(
            child: Container(
              width: wheelSize,
              height: wheelSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.8),
                border: Border.all(color: Colors.black12, width: 2),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  buildFullWheelImage(wheelSize),
                  if (clickedIndex == null)
                    ...List.generate(5, (index) {
                      double startAngle = -pi / 2;
                      double angle = startAngle + (2 * pi / 5) * index;
                      double radius = mainCircleRadius - (wheelSize / 10);

                      if (index == 0) radius -= 15; // Bull inward

                      double buttonRadius = wheelSize / 10;
                      if (index == 0) buttonRadius *= 1.3; // Bull bigger
                      else buttonRadius *= 1.1; // Others slightly bigger

                      Offset buttonOffset = Offset(
                        mainCircleRadius + cos(angle) * radius,
                        mainCircleRadius + sin(angle) * radius,
                      );
                      return buildButton(index, buttonRadius, buttonOffset);
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

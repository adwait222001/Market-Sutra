import 'package:flutter/material.dart';
import 'package:marketsutra/News/commonnews.dart';
import 'package:marketsutra/datapage/IndexGraphCard.dart';
import 'package:marketsutra/datapage/livindex_market.dart';
import 'package:marketsutra/datapage/livesearch.dart';
import 'package:marketsutra/mainbase/sidebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusNode _pageFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // ✅ prevents AppBar from moving
        drawer: sidebar(),
        appBar: AppBar(
          toolbarHeight: 130, // taller AppBar
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              iconSize: 40,
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10),
            child: Search(), // search bar inside AppBar
          ),
        ),
        body: SingleChildScrollView(
          child:Column(children: [
            SizedBox(height: 10),
            IndexPage(apiUrl: 'YOUR_IP/livedata',),
            SizedBox(height: 40),
            //SizedBox(height: 40),
           //IndexGraphCard(),
            //SizedBox(height: 20),
            commonnews(),
            SizedBox(height: 50),
            IndexGraphCard(),


          ],)
        ),
      ),
    );
  }
}

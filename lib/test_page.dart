import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: const Icon(Icons.settings, size: 36, color: Colors.white),
        title: const Text(
          "Test Page",
          style: TextStyle(color: Colors.white, fontSize: 36),
        ),
        actions:const [
          Icon(Icons.notification_add, size: 25, color: Colors.white),
          SizedBox(width: 10,),
          Icon(Icons.person, size: 25, color: Colors.white)
        ]
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Hello World,", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 30),),
              const Text("Welcome to our test page, we are glad to have you here.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 16),),
              const SizedBox(height: 10),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.access_time, color: Colors.black),
                  Text("16 mins", style: TextStyle(
                    color: Colors.black
                  ),),
                  SizedBox(width: 5),
          
                  Icon(Icons.web_asset, color: Colors.black),
                  Text("Oladele Usman", style: TextStyle(
                      color: Colors.black
                  ),),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                  width: double.infinity,
                  height: 260,
                  child: Image.asset("asset/images/mango-9.jpg", fit: BoxFit.fitWidth,)),
              const Text("Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. \n\n Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. \n\n Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here. Welcome to our test page, we are glad to have you here.", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16),),
          
            ]
          ),
        )
      ),
    );
  }
}

// lib/Screens/order_confirmation_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  
  const OrderConfirmationScreen({Key? key, required this.orderId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Confirmation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 100,
                color: MangoPalette.green500,
              ),
              SizedBox(height: 24),
              Text(
                'Order Placed Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Order ID: $orderId',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Thank you for your purchase!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? MangoPalette.grey300 : MangoPalette.grey700,
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Get.offAllNamed('/home'); // Navigate to home
                },
                child: Text('Continue Shopping'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MangoPalette.green500,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
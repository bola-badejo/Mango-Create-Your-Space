// lib/Store/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/Store/models/cart_item.dart';
import 'package:mango/Store/screens/order_confirmation_screen.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class CartScreen extends GetView<CartController> {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
      appBar: AppBar(
        leading: IconButton(
        tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: isDarkMode ? MangoPalette.black : Colors.white,),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'My Cart',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : MangoPalette.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
        tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline,
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
            onPressed: () {
              _showClearCartBottomSheet(context, isDarkMode);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<CartItem>>(
        stream: controller.getCartItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final cartItems = snapshot.data ?? [];

          if (cartItems.isEmpty) {
            return _buildEmptyCart(isDarkMode);
          }

          return Column(
            children: [
              Expanded(
                child: OptimizedListView(
                  padding: EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    return _buildCartItem(cartItems[index], context);
                  },
                ),
              ),
              _buildCartSummary(cartItems, isDarkMode, context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
          ),
          SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : MangoPalette.grey600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add items to get started',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white54 : MangoPalette.grey500,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.back(),
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
    );
  }

  Widget _buildCartItem(CartItem item, context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDarkMode ? MangoPalette.grey850 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: MangoPalette.grey200,
                        child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: MangoPalette.grey200,
                        child: Icon(Icons.image_not_supported),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: MangoPalette.grey200,
                      child: Icon(Icons.image),
                    ),
            ),
            SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.vendorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₦${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MangoPalette.green500,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
        tooltip: 'Remove',
                            icon: Icon(Icons.remove_circle_outline, size: 24),
                            onPressed: () {
                              if (item.quantity > 1) {
                                controller.updateQuantity(
                                  item.id,
                                  item.quantity - 1,
                                );
                              } else {
                                controller.removeFromCart(item.id);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                          Container(
                            width: 40,
                            child: Text(
                              item.quantity.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
        tooltip: 'Add',
                            icon: Icon(Icons.add_circle_outline, size: 24),
                            onPressed: () {
                              controller.updateQuantity(
                                item.id,
                                item.quantity + 1,
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                          SizedBox(width: 8),
                          IconButton(
        tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              controller.removeFromCart(item.id);
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(
    List<CartItem> cartItems,
    bool isDarkMode,
    BuildContext context,
  ) {
    final summary = CartSummary.fromCartItems(cartItems);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey850 : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
          ),
        ),
      ),
      child: Column(
        children: [
          // Summary details
          _buildSummaryRow(
            'Subtotal',
            '₦${summary.subtotal.toStringAsFixed(2)}',
            context,
          ),
          SizedBox(height: 8),
          _buildSummaryRow(
            'Shipping',
            summary.shipping == 0
                ? 'Free'
                : '₦${summary.shipping.toStringAsFixed(2)}',
            context,
          ),
          SizedBox(height: 8),
          _buildSummaryRow(
            'Tax (7.5%)',
            '₦${summary.tax.toStringAsFixed(2)}',
            context,
          ),
          Divider(height: 24),
          _buildSummaryRow(
            'Total',
            '₦${summary.total.toStringAsFixed(2)}',
            context,
            isTotal: true,
          ),
          SizedBox(height: 16),
          // Checkout button
          Obx(
            () => ElevatedButton(
              onPressed: controller.isCheckingOut.value
                  ? null
                  : () => _showCheckoutBottomSheet(context, isDarkMode),
              child: controller.isCheckingOut.value
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Proceed to Checkout', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MangoPalette.green500,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    BuildContext context, {
    bool isTotal = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal
                ? (isDarkMode ? Colors.white : MangoPalette.black)
                : (isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal
                ? MangoPalette.green500
                : (isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600),
          ),
        ),
      ],
    );
  }

  void _showClearCartBottomSheet(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey850 : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey300,
                borderRadius: BorderRadius.circular(MangoRadius.xs),
              ),
            ),
            SizedBox(height: 20),
            // Icon
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, size: 40, color: Colors.red),
            ),
            SizedBox(height: 20),
            // Title
            Text(
              'Clear Cart?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : MangoPalette.black,
              ),
            ),
            SizedBox(height: 12),
            // Description
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Are you sure you want to remove all items from your cart? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                ),
              ),
            ),
            SizedBox(height: 24),
            // Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDarkMode
                            ? Colors.white
                            : MangoPalette.black,
                        side: BorderSide(
                          color: isDarkMode
                              ? MangoPalette.grey600
                              : MangoPalette.grey300,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        controller.clearCart();
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                      ),
                      child: Text('Clear Cart'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCheckoutBottomSheet(BuildContext context, bool isDarkMode) {
    final shippingController = TextEditingController();
    String paymentMethod = 'Credit Card';
    RxString selectedPaymentMethod = 'Credit Card'.obs;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey850 : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey300,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                ),
                SizedBox(height: 20),
                // Title
                Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Complete your order',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
                SizedBox(height: 24),
                // Order Summary
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? MangoPalette.grey400
                                    : MangoPalette.grey600,
                              ),
                            ),
                            Text(
                              '₦${controller.subtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : MangoPalette.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Shipping',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? MangoPalette.grey400
                                    : MangoPalette.grey600,
                              ),
                            ),
                            Text(
                              controller.shipping == 0
                                  ? 'Free'
                                  : '₦${controller.shipping.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : MangoPalette.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tax (7.5%)',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? MangoPalette.grey400
                                    : MangoPalette.grey600,
                              ),
                            ),
                            Text(
                              '₦${controller.tax.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : MangoPalette.black,
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : MangoPalette.black,
                              ),
                            ),
                            Text(
                              '₦${controller.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: MangoPalette.green500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Shipping Address
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: shippingController,
                    maxLines: 3,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Shipping Address',
                      labelStyle: TextStyle(
                        color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                      ),
                      hintText: 'Enter your full shipping address',
                      hintStyle: TextStyle(
                        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                        borderSide: BorderSide(color: MangoPalette.green500),
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? MangoPalette.grey800
                          : MangoPalette.grey50,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Payment Method
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : MangoPalette.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Obx(
                        () => Column(
                          children: [
                            _buildPaymentOption(
                              'Credit Card',
                              Icons.credit_card,
                              selectedPaymentMethod.value == 'Credit Card',
                              () => selectedPaymentMethod.value = 'Credit Card',
                              isDarkMode,
                            ),
                            _buildPaymentOption(
                              'PayPal',
                              Icons.paypal,
                              selectedPaymentMethod.value == 'PayPal',
                              () => selectedPaymentMethod.value = 'PayPal',
                              isDarkMode,
                            ),
                            _buildPaymentOption(
                              'Bank Transfer',
                              Icons.account_balance,
                              selectedPaymentMethod.value == 'Bank Transfer',
                              () =>
                                  selectedPaymentMethod.value = 'Bank Transfer',
                              isDarkMode,
                            ),
                            _buildPaymentOption(
                              'Cash on Delivery',
                              Icons.money,
                              selectedPaymentMethod.value == 'Cash on Delivery',
                              () => selectedPaymentMethod.value =
                                  'Cash on Delivery',
                              isDarkMode,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Buttons
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDarkMode
                                ? Colors.white
                                : MangoPalette.black,
                            side: BorderSide(
                              color: isDarkMode
                                  ? MangoPalette.grey600
                                  : MangoPalette.grey300,
                            ),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.md),
                            ),
                          ),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Obx(
                          () => ElevatedButton(
                            onPressed: controller.isCheckingOut.value
                                ? null
                                : () async {
                                    if (shippingController.text.isEmpty) {
                                      Get.snackbar(
                                        'Error',
                                        'Please enter shipping address',
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                      return;
                                    }

                                    final result = await controller.checkout(
                                      shippingAddress: shippingController.text,
                                      paymentMethod:
                                          selectedPaymentMethod.value,
                                    );

                                    if (result['success']) {
                                      Get.back(); // Close bottom sheet
                                      Get.back(); // Go back to previous screen
                                      Get.to(
                                        () => OrderConfirmationScreen(
                                          orderId: result['orderId'],
                                        ),
                                      );
                                    }
                                  },
                            child: controller.isCheckingOut.value
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Place Order',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MangoPalette.green500,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(MangoRadius.md),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return MangoPressable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MangoPalette.green500.withOpacity(0.1)
              : (isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50),
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: isSelected
                ? MangoPalette.green500
                : (isDarkMode ? MangoPalette.grey700 : MangoPalette.grey200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? MangoPalette.green500
                  : (isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600),
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? MangoPalette.green500
                      : (isDarkMode ? Colors.white : MangoPalette.black),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: MangoPalette.green500, size: 20),
          ],
        ),
      ),
    );
  }
}

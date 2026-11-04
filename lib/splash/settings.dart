
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mango/app/themes/app_themes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('Change app appearance'),
            onTap: () => _showThemeDialog(context),
          ),
          
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ThemeSelectionDialog(),
    );
  }
}

class ThemeSelectionDialog extends StatelessWidget {
  final SharedPreferences _prefs = Get.find();

  ThemeSelectionDialog({super.key});

  Future<void> _changeTheme(bool isDarkMode, context) async {
    try {
      await _prefs.setBool('isDarkMode', isDarkMode);
      Get.changeThemeMode(isDarkMode ? ThemeMode.dark : ThemeMode.light);
      Get.back();
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to change theme: $e', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: const Text('Light Mode'),
            onTap: () => _changeTheme(false, context),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            onTap: () => _changeTheme(true, context),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('System Default'),
            onTap: () async {
              await _prefs.remove('isDarkMode');
              Get.changeThemeMode(ThemeMode.system);
              Get.back();
            },
          ),
        ],
      ),
    );
  }
}
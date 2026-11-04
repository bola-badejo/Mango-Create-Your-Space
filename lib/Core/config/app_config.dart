
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  static late final String appName;
  static late final String appVersion;
  static late final bool isProduction;
  static late final Logger logger;

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
    
    appName = const String.fromEnvironment('APP_NAME', defaultValue: 'Mango');
    appVersion = const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
    isProduction = const bool.fromEnvironment('PRODUCTION', defaultValue: false);
    
    logger = Logger(
      level: isProduction ? Level.warning : Level.debug,
      printer: PrettyPrinter(
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );
  }
}
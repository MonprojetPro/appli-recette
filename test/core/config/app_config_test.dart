import 'package:appli_recette/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('webBaseUrl has default value', () {
      expect(AppConfig.webBaseUrl, isNotEmpty);
      expect(AppConfig.webBaseUrl, contains('vercel.app'));
    });

    test('isDevelopment returns true for development flavor', () {
      const config = AppConfig(
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-key',
        flavor: AppFlavor.development,
      );
      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
    });

    test('isProduction returns true for production flavor', () {
      const config = AppConfig(
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-key',
        flavor: AppFlavor.production,
      );
      expect(config.isProduction, isTrue);
      expect(config.isDevelopment, isFalse);
    });

    test('fields are accessible', () {
      const config = AppConfig(
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'my-anon-key',
        flavor: AppFlavor.development,
      );
      expect(config.supabaseUrl, 'https://test.supabase.co');
      expect(config.supabaseAnonKey, 'my-anon-key');
    });
  });

  group('PWA Manifest constants', () {
    test('webBaseUrl is not empty', () {
      expect(AppConfig.webBaseUrl, isNotEmpty);
    });
  });
}

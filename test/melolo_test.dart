import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/services/api/api_platform.dart';
import 'package:livego_premium/services/drama_source.dart';
import 'package:livego_premium/services/melolo/melolo_config.dart';
import 'package:livego_premium/services/melolo/melolo_source.dart';

void main() {
  group('Melolo Source & Integration Tests', () {
    test('MeloloConfig properties are properly set', () {
      expect(MeloloConfig.baseUrl, 'https://api.tmtreader.com');
      expect(MeloloConfig.aid, '645713');
      expect(MeloloConfig.deviceId, '7514640337227908615');
      expect(MeloloConfig.appName, 'melolo');
      expect(MeloloConfig.categories.length, greaterThanOrEqualTo(10));
      expect(MeloloConfig.categories, contains('Romance'));
      expect(MeloloConfig.categories, contains('Billionaire'));
      expect(MeloloConfig.categories, contains('Rebirth'));
    });

    test('MeloloSource implements DramaSource correctly', () {
      final source = MeloloSource();
      expect(source.slug, 'melolo');
      expect(source.label, 'Melolo');
      expect(source.categories, MeloloConfig.categories);
    });

    test('DramaSourceRegistry registers and handles melolo', () {
      expect(DramaSourceRegistry.handles('melolo'), isTrue);
      final source = DramaSourceRegistry.forSlug('melolo');
      expect(source, isNotNull);
      expect(source, isA<MeloloSource>());
      expect(source!.categories, contains('Romance'));
    });

    test('LiveGoApiPlatforms includes melolo and real categories', () {
      expect(LiveGoApiPlatforms.supports('melolo'), isTrue);
      expect(LiveGoApiPlatforms.tvStarterSlugs, contains('melolo'));

      final platform = LiveGoApiPlatforms.bySlug('melolo');
      expect(platform.slug, 'melolo');
      expect(platform.name, 'Melolo');
      expect(platform.categories, contains('Romance'));
      expect(platform.categories, contains('Billionaire'));
    });
  });
}

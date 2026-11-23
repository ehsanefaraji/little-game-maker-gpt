import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('premium platformer art assets are bundled', () async {
    for (final asset in [
      'assets/images/fox_hero_animations.png',
      'assets/images/forest_slime_animations.png',
      'assets/images/sun_coin_animations.png',
      'assets/images/adventure_tiles_atlas.png',
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}

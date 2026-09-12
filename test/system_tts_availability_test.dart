import 'package:epitaka/features/settings/services/system_tts_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isVoiceUsable', () {
    test('rejects voices flagged notInstalled', () {
      expect(
        SystemTtsAvailability.isVoiceUsable({
          'name': 'si-LK-voice',
          'locale': 'si-LK',
          'features': 'notInstalled',
        }),
        isFalse,
      );
    });

    test('accepts installed voices without flags', () {
      expect(
        SystemTtsAvailability.isVoiceUsable({
          'name': 'si-LK-voice',
          'locale': 'si-LK',
          'features': '',
        }),
        isTrue,
      );
    });
  });

  group('localVoicesFor', () {
    final voices = [
      {
        'name': 'si-listed-but-missing',
        'locale': 'si-LK',
        'features': 'notInstalled',
        'network_required': '0',
      },
      {
        'name': 'si-network',
        'locale': 'si-LK',
        'features': '',
        'network_required': '1',
      },
      {
        'name': 'si-local',
        'locale': 'si-LK',
        'features': '',
        'network_required': '0',
      },
      {'name': 'en-voice', 'locale': 'en-US', 'features': ''},
    ];

    test('listed-but-missing voice is not local', () {
      final local = SystemTtsAvailability.localVoicesFor(voices, 'si');
      expect(local.map((v) => v['name']), contains('si-local'));
      expect(
        local.map((v) => v['name']),
        isNot(contains('si-listed-but-missing')),
      );
    });

    test('network voice is usable but not local', () {
      final usable = SystemTtsAvailability.usableVoicesFor(voices, 'si');
      expect(usable.map((v) => v['name']), contains('si-network'));
      final local = SystemTtsAvailability.localVoicesFor(voices, 'si');
      expect(local.map((v) => v['name']), isNot(contains('si-network')));
    });

    test('locale matching handles dash and underscore', () {
      expect(SystemTtsAvailability.localeMatches('si-LK', 'si'), isTrue);
      expect(SystemTtsAvailability.localeMatches('si_LK', 'si'), isTrue);
      expect(SystemTtsAvailability.localeMatches('en-US', 'si'), isFalse);
    });
  });
}

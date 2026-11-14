import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/utils/sri_lanka_nic.dart';

// The same cases as backend/test/nic.test.js, so the app and the server agree.
void main() {
  group('valid NICs', () {
    for (final String nic in [
      '821940129V', // old format, man, born 1982
      '821940129v', // lower case letter
      '853400937 V', // spaces are ignored
      '858400937x', // old format ending in X, woman (840 = 340 + 500)
      '198219400129', // new format
      '200012300045', // new format, born 2000
      '199850600123', // new format, woman (506 = 6 + 500)
      '840600129V', // day 60 = 29 Feb, and 1984 is a leap year
    ]) {
      test(nic, () => expect(nicError(nic), isNull));
    }
  });

  group('invalid NICs', () {
    test('empty', () => expect(nicError(''), 'Enter your NIC number.'));
    test('null', () => expect(nicError(null), 'Enter your NIC number.'));
    for (final String nic in [
      '82194012V', // too short
      '8219401299', // 10 digits and no letter
      '821940129A', // the letter must be V or X
      '12345',
      'ABCDEFGHIJKL',
      '19821940012', // 11 digits
    ]) {
      test(
        '$nic has the wrong shape',
        () => expect(nicError(nic), nicFormatMessage),
      );
    }
    for (final String nic in [
      '820000129V', // day 0
      '823670129V', // day 367
      '825000129V', // 500 is neither a man's nor a woman's day
      '828670129V', // woman's day 367
      '830600129V', // 29 Feb in 1983, which was not a leap year
    ]) {
      test('$nic has an impossible birth date', () {
        expect(
          nicError(nic),
          'This NIC has an invalid birth date. Check the digits.',
        );
      });
    }
    test('born in the future', () {
      expect(
        nicError('203012300045'),
        'This NIC has an invalid birth year. Check the digits.',
      );
    });
    test('too young to hold a NIC', () {
      final DateTime now = DateTime(2026, 6, 1);
      expect(
        nicError('201112300045', now: now),
        'This NIC has an invalid birth year. Check the digits.',
      );
      expect(nicError('201012300045', now: now), isNull);
    });
    test('before 1900', () {
      expect(
        nicError('189912300045'),
        'This NIC has an invalid birth year. Check the digits.',
      );
    });
  });

  test('normalizeNic upper-cases and removes spaces', () {
    expect(normalizeNic(' 821940129v '), '821940129V');
    expect(normalizeNic('1982 1940 0129'), '198219400129');
    expect(normalizeNic(null), '');
  });
}

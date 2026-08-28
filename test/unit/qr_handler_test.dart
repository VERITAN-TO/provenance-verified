import 'package:test/test.dart';
import 'package:provenance_verified_app/core/routing/qr_handler.dart';

void main() {
  group('QrHandler — valid inputs', () {
    test('direct PV ID is valid', () {
      final result = QrHandler.parse('PV-TEST-T4D004');
      expect(result, isA<QrValid>());
      expect((result as QrValid).publicId, 'PV-TEST-T4D004');
    });

    test('DET-V1 format is valid', () {
      final result = QrHandler.parse('DET-V1-0CC5D81A36B661A7E9DBE0D2');
      expect(result, isA<QrValid>());
    });

    test('canonical HTTPS URL is valid', () {
      final result =
          QrHandler.parse('https://provenanceverified.org/verify/PV-TEST-S1-001');
      expect(result, isA<QrValid>());
      expect((result as QrValid).publicId, 'PV-TEST-S1-001');
    });

    test('pv:// scheme URL is valid', () {
      final result = QrHandler.parse('pv://verify/PV-TEST-S3-001');
      expect(result, isA<QrValid>());
    });

    test('query parameter id is extracted', () {
      final result = QrHandler.parse(
          'https://provenanceverified.org/verify?id=PV-TEST-T4D004');
      expect(result, isA<QrValid>());
      expect((result as QrValid).publicId, 'PV-TEST-T4D004');
    });
  });

  group('QrHandler — malformed and deceptive inputs', () {
    test('empty string is invalid', () {
      expect(QrHandler.parse(''), isA<QrInvalid>());
    });

    test('null is invalid', () {
      expect(QrHandler.parse(null), isA<QrInvalid>());
    });

    test('wrong domain is invalid', () {
      final result = QrHandler.parse('https://evil.com/verify/PV-TEST-T4D004');
      expect(result, isA<QrInvalid>());
      expect((result as QrInvalid).reason, contains('Untrusted domain'));
    });

    test('http (not https) is rejected', () {
      final result =
          QrHandler.parse('http://provenanceverified.org/verify/PV-TEST-T4D004');
      expect(result, isA<QrInvalid>());
    });

    test('javascript: scheme is rejected', () {
      expect(QrHandler.parse('javascript:alert(1)'), isA<QrInvalid>());
    });

    test('data: URI is rejected', () {
      expect(
          QrHandler.parse('data:text/html,<script>alert(1)</script>'),
          isA<QrInvalid>());
    });

    test('injection-like input is rejected', () {
      expect(QrHandler.parse("'; DROP TABLE assets;--"), isA<QrInvalid>());
    });

    test('ftp:// is rejected', () {
      expect(
          QrHandler.parse('ftp://provenanceverified.org/PV-TEST-T4D004'),
          isA<QrInvalid>());
    });

    test('URL with no PV ID path is invalid', () {
      expect(QrHandler.parse('https://provenanceverified.org/about'),
          isA<QrInvalid>());
    });

    test('lookalike domain is rejected', () {
      expect(
          QrHandler.parse(
              'https://pr0venanceverified.org/verify/PV-TEST-T4D004'),
          isA<QrInvalid>());
    });
  });

  group('isValidPublicId', () {
    test('valid PV- format', () => expect(QrHandler.isValidPublicId('PV-TEST-T4D004'), true));
    test('valid DET-V1 format', () {
      expect(QrHandler.isValidPublicId('DET-V1-0CC5D81A36B661A7E9DBE0D2'), true);
    });
    test('lowercase is normalized', () {
      expect(QrHandler.isValidPublicId('pv-test-t4d004'), true);
    });
    test('empty string is invalid', () => expect(QrHandler.isValidPublicId(''), false));
    test('null is invalid', () => expect(QrHandler.isValidPublicId(null), false));
    test('arbitrary string is invalid', () {
      expect(QrHandler.isValidPublicId('hello world'), false);
    });
  });
}

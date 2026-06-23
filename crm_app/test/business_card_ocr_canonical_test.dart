import 'package:flutter_test/flutter_test.dart';
import 'package:crm/core/services/docstrange_extraction_service.dart';
import 'package:crm/core/utils/business_card_ocr_canonical.dart';

void main() {
  group('DocStrangeExtractionService.parseExtractResponse', () {
    test('parses official result.json.content shape', () {
      final parsed = DocStrangeExtractionService.parseExtractResponse({
        'success': true,
        'status': 'completed',
        'record_id': 'abc-123',
        'processing_time': 1.5,
        'result': {
          'json': {
            'content': {
              'name': 'Jane Doe',
              'company': 'Acme Corp',
              'location': 'Dhaka, Bangladesh',
              'designation': 'Manager',
              'mobile': '+15551234567',
              'email': 'jane@acme.com',
            },
            'metadata': {
              'confidence_score': {
                'name': 98,
                'email': 95,
              },
            },
          },
        },
      });

      expect(parsed.content['name'], 'Jane Doe');
      expect(parsed.content['company'], 'Acme Corp');
      expect(parsed.recordId, 'abc-123');
      expect(parsed.processingTimeSeconds, 1.5);
      expect(parsed.confidenceScores?['name'], 98);
    });

    test('parses stringified json content', () {
      final parsed = DocStrangeExtractionService.parseExtractResponse({
        'result': {
          'json': {
            'content': '{"name":"Bob","email":"bob@test.com"}',
          },
        },
      });

      expect(parsed.content['name'], 'Bob');
      expect(parsed.content['email'], 'bob@test.com');
    });
  });

  group('canonicalizeBusinessCardOcr', () {
    test('maps DocStrange flat content keys', () {
      final result = canonicalizeBusinessCardOcr({
        'name': 'Jane Doe',
        'company': 'Acme Corp',
        'location': '123 Main St, New York',
        'designation': 'Sales Manager',
        'mobile': '+1 555 123 4567',
        'email': 'jane@acme.com',
      });

      expect(result.name, 'Jane Doe');
      expect(result.companyName, 'Acme Corp');
      expect(result.companyLocation, '123 Main St, New York');
      expect(result.designation, 'Sales Manager');
      expect(result.mobile, '+15551234567');
      expect(result.email, 'jane@acme.com');
    });

    test('unwraps nested result.json.content', () {
      final result = canonicalizeBusinessCardOcr({
        'success': true,
        'result': {
          'json': {
            'content': {
              'name': 'John Smith',
              'company': 'Globex Ltd',
              'address': 'London, UK',
              'designation': 'Director',
              'mobile': '01712345678',
              'email': 'john@globex.com',
            },
          },
        },
      });

      expect(result.name, 'John Smith');
      expect(result.companyName, 'Globex Ltd');
      expect(result.companyLocation, 'London, UK');
      expect(result.designation, 'Director');
      expect(result.mobile, '01712345678');
      expect(result.email, 'john@globex.com');
    });

    test('infers email and phone from free text values', () {
      final result = canonicalizeBusinessCardOcr({
        'line1': 'Rahim Uddin',
        'line2': 'rahim@example.org',
        'line3': '01911223344',
      });

      expect(result.name, 'Rahim Uddin');
      expect(result.email, 'rahim@example.org');
      expect(result.mobile, '01911223344');
    });
  });

  group('mergeBusinessCardContacts', () {
    test('fills empty fields from the other side', () {
      const front = CanonicalBusinessCardContact(
        name: 'Jane Doe',
        companyName: 'Acme Corp',
        designation: 'Manager',
      );
      const back = CanonicalBusinessCardContact(
        companyLocation: '123 Main St, NYC',
        mobile: '+15551234567',
        email: 'jane@acme.com',
      );

      final merged = mergeBusinessCardContacts(front, back);

      expect(merged.name, 'Jane Doe');
      expect(merged.companyName, 'Acme Corp');
      expect(merged.designation, 'Manager');
      expect(merged.companyLocation, '123 Main St, NYC');
      expect(merged.mobile, '+15551234567');
      expect(merged.email, 'jane@acme.com');
    });

    test('prefers primary when both sides have the same field', () {
      const front = CanonicalBusinessCardContact(
        name: 'Jane Doe',
        mobile: '+15551111111',
      );
      const back = CanonicalBusinessCardContact(
        name: 'J. Doe',
        mobile: '+15552222222',
      );

      final merged = mergeBusinessCardContacts(front, back);

      expect(merged.name, 'Jane Doe');
      expect(merged.mobile, '+15551111111');
    });
  });

  group('mergeBusinessCardPages', () {
    test('merges three pages in order', () {
      final merged = mergeBusinessCardPages(const [
        CanonicalBusinessCardContact(name: 'Jane Doe'),
        CanonicalBusinessCardContact(email: 'jane@acme.com'),
        CanonicalBusinessCardContact(mobile: '+15551234567'),
      ]);

      expect(merged.name, 'Jane Doe');
      expect(merged.email, 'jane@acme.com');
      expect(merged.mobile, '+15551234567');
    });
  });

  group('matchCompanyIdByName', () {
    test('matches exact and partial company names', () {
      final companies = [
        (id: '1', name: 'Acme Corporation'),
        (id: '2', name: 'Globex'),
      ];

      expect(matchCompanyIdByName(companies, 'Acme Corporation'), '1');
      expect(matchCompanyIdByName(companies, 'acme'), '1');
      expect(matchCompanyIdByName(companies, 'Unknown'), isNull);
    });
  });
}

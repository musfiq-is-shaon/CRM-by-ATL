import 'package:flutter_test/flutter_test.dart';
import 'package:crm/core/services/docstrange_extraction_service.dart';
import 'package:crm/core/utils/business_card_ocr_canonical.dart';
import 'package:crm/core/utils/company_name_match.dart';

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

    test('ignores case and legal suffix differences', () {
      final companies = [
        (id: '1', name: 'Bongo Tech Limited'),
        (id: '2', name: 'Globex Pvt Ltd'),
      ];

      expect(matchCompanyIdByName(companies, 'BONGO TECH LTD'), '1');
      expect(matchCompanyIdByName(companies, 'bongo tech'), '1');
      expect(matchCompanyIdByName(companies, 'Globex Limited'), '2');
      expect(matchCompanyIdByName(companies, 'GLOBEX PVT. LTD.'), '2');
    });

    test('matches capitalization and full legal name variants', () {
      final companies = [
        (id: '1', name: 'Grameenphone Limited'),
        (id: '2', name: 'The Acme Corporation'),
      ];

      expect(matchCompanyIdByName(companies, 'GRAMEENPHONE LTD'), '1');
      expect(matchCompanyIdByName(companies, 'grameenphone'), '1');
      expect(matchCompanyIdByName(companies, 'ACME CORP'), '2');
      expect(matchCompanyIdByName(companies, 'Acme Corporation'), '2');
    });

    test('matches dotted abbreviations and ampersand', () {
      final companies = [
        (id: '1', name: 'Smith and Sons Limited'),
        (id: '2', name: 'Johnson & Johnson Pvt. Ltd.'),
      ];

      expect(matchCompanyIdByName(companies, 'SMITH & SONS LTD'), '1');
      expect(matchCompanyIdByName(companies, 'Johnson and Johnson'), '2');
      expect(matchCompanyIdByName(companies, 'JOHNSON & JOHNSON PVT LTD'), '2');
    });

    test('matches technology vs tech and international acronym', () {
      final companies = [
        (id: '1', name: 'Bongo Technology Limited'),
        (id: '2', name: 'International Business Machines'),
      ];

      expect(matchCompanyIdByName(companies, 'BONGO TECH LTD'), '1');
      expect(matchCompanyIdByName(companies, 'IBM'), '2');
    });

    test('matches hyphenated and extra punctuation from OCR', () {
      final companies = [
        (id: '1', name: 'Hewlett Packard Enterprise'),
      ];

      expect(matchCompanyIdByName(companies, 'Hewlett-Packard Enterprise'), '1');
      expect(matchCompanyIdByName(companies, 'HEWLETT PACKARD'), '1');
    });

    test('ignores legal-only OCR text and prefers distinctive names', () {
      final companies = [
        (id: '1', name: 'Alpha Industries Limited'),
        (id: '2', name: 'Beta Group Pvt Ltd'),
      ];

      expect(matchCompanyIdByName(companies, 'Limited'), isNull);
      expect(matchCompanyIdByName(companies, 'Group Ltd'), isNull);
      expect(matchCompanyIdByName(companies, 'Pvt. Ltd.'), isNull);
      expect(matchCompanyIdByName(companies, 'Alpha Group Limited'), '1');
      expect(matchCompanyIdByName(companies, 'Beta'), '2');
    });

    test('picks best core-name match when multiple companies share legal suffixes', () {
      final companies = [
        (id: '1', name: 'Square Pharmaceuticals Ltd'),
        (id: '2', name: 'Beximco Pharmaceuticals Ltd'),
      ];

      expect(matchCompanyIdByName(companies, 'Square Pharma Ltd'), '1');
      expect(matchCompanyIdByName(companies, 'BEXIMCO PHARMACEUTICALS'), '2');
    });

    test('matches when OCR includes head office suffix noise', () {
      final companies = [
        (id: '1', name: 'Unilever Bangladesh Limited'),
      ];

      expect(
        matchCompanyIdByName(companies, 'UNILEVER BANGLADESH LTD\nHead Office'),
        '1',
      );
    });

    test('suggests similar companies without auto-selecting ambiguous matches', () {
      final companies = [
        (id: '1', name: 'Square Pharmaceuticals Ltd'),
        (id: '2', name: 'Beximco Pharmaceuticals Ltd'),
      ];

      final result = rankCompaniesByName(companies, 'Pharmaceuticals Ltd');
      expect(result.autoSelectId, isNull);
      expect(result.suggestions.length, 2);
      expect(
        result.suggestions.map((c) => c.id),
        containsAll(['1', '2']),
      );
    });

    test('auto-selects only when OCR clearly matches one company', () {
      final companies = [
        (id: '1', name: 'Square Pharmaceuticals Ltd'),
        (id: '2', name: 'Beximco Pharmaceuticals Ltd'),
      ];

      final square = rankCompaniesByName(companies, 'Square Pharma Ltd');
      expect(square.autoSelectId, '1');
      expect(square.suggestions.first.id, '1');
    });

    test('suggests companies with OCR spelling mistakes', () {
      final companies = [
        (id: '1', name: 'Grameenphone Limited'),
        (id: '2', name: 'Robi Axiata Limited'),
        (id: '3', name: 'Banglalink Digital Communications'),
      ];

      final typo = rankCompaniesByName(companies, 'Grameenphne Ltd');
      expect(typo.autoSelectId, '1');
      expect(typo.suggestions.map((c) => c.id), contains('1'));

      final squareTypo = rankCompaniesByName(
        [
          (id: '4', name: 'Square Pharmaceuticals Ltd'),
          (id: '5', name: 'Beximco Pharmaceuticals Ltd'),
        ],
        'Sqare Pharmaceuticls Ltd',
      );
      expect(squareTypo.suggestions.map((c) => c.id), contains('4'));
      expect(squareTypo.suggestions.first.id, '4');
    });
  });

  group('normalizeCompanyNameForMatch', () {
    test('strips punctuation and legal suffixes', () {
      expect(normalizeCompanyNameForMatch('Acme Corp.'), 'acme');
      expect(normalizeCompanyNameForMatch('ACME LIMITED'), 'acme');
      expect(normalizeCompanyNameForMatch('Globex Pvt. Ltd.'), 'globex');
      expect(normalizeCompanyNameForMatch('L.L.C. Widgets'), 'widgets');
      expect(normalizeCompanyNameForMatch('The Acme Corporation'), 'acme');
      expect(
        normalizeCompanyNameForMatch('Bongo Technology Limited'),
        'bongo technology',
      );
    });
  });

  group('cleanOcrCompanyName', () {
    test('keeps first line and drops office suffix noise', () {
      expect(
        cleanOcrCompanyName('Acme Corp Ltd\nHead Office'),
        'Acme Corp Ltd',
      );
      expect(
        cleanOcrCompanyName('Globex Branch Office'),
        'Globex',
      );
    });
  });
}

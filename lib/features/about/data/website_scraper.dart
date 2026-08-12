import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class WebsiteScraper {
  final Uri url = Uri.parse('https://www.behumancommunity.com');

  Future<Map<String, String>> fetch() async {
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) throw Exception('Bad status');

      final body = resp.body;

      // very light-weight extraction using RegExp (fallback when no html parser available)
      // `dotAll` is what lets the body span newlines; the character class this
      // replaced ("[sS]") only ever matched a literal s or S.
      String extractFirst(String tag) {
        final re = RegExp('<$tag[^>]*>(.*?)</$tag>', caseSensitive: false, dotAll: true);
        final m = re.firstMatch(body);
        if (m == null) return '';
        return _stripTags(m.group(1) ?? '');
      }

      String extractMultiple(String tag, int count) {
        final re = RegExp('<$tag[^>]*>(.*?)</$tag>', caseSensitive: false, dotAll: true);
        final matches = re.allMatches(body).take(count).map((m) => _stripTags(m.group(1) ?? '')).toList();
        return matches.join('\n\n');
      }

      final mission = _normalizeText(extractFirst('h1'));
      final vision = _normalizeText(extractFirst('h2'));
      final description = _normalizeText(extractMultiple('p', 3));

      // If everything is empty, consider it a failure
      if (mission.isEmpty && vision.isEmpty && description.isEmpty) {
        throw Exception('No meaningful content');
      }

      return {
        'mission': mission,
        'vision': vision,
        'description': description,
      };
    } on TimeoutException catch (_) {
      return _fallback();
    } catch (_) {
      return _fallback();
    }
  }

  Map<String, String> _fallback() {
    return {
      'mission': 'نحن نعمل من أجل إنسانية أفضل ودعم المجتمعات في حالات الأزمات.',
      'vision': 'عالم يتمتع فيه الجميع بكرامة وفرص متكافئة.',
      'description': 'Be Human هي منظمة مجتمع مدني تعمل على تقديم المساعدة الطارئة والبرامج التنموية والدعم النفسي والاجتماعي للمجتمعات المتأثرة. نركز على الشفافية، الكفاءة، والعمل الجماعي لبناء مستقبل أفضل.',
    };
  }
}

final websiteScraperProvider = Provider((ref) => WebsiteScraper());

String _normalizeText(String t) => t.replaceAll(RegExp(r"\s+"), ' ').trim();

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

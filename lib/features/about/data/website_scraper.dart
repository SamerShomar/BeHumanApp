import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:be_human_app/features/projects/domain/project.dart';

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

  /// Reads the project list off the website.
  ///
  /// A caveat worth stating plainly: this parser was written without being
  /// able to open the site — the build environment blocks it — so the
  /// selectors below are the shapes most sites use, not ones confirmed
  /// against this one. It is deliberately built to return an empty list
  /// rather than nonsense, and the admin screen says so and offers to add
  /// projects by hand, which always works.
  ///
  /// Nothing else in the app depends on this: projects live in Firestore, and
  /// an import is one way to fill them, not the only way.
  Future<List<Project>> fetchProjects() async {
    final String body;
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];
      body = response.body;
    } catch (_) {
      return const [];
    }

    return parseProjects(body, sourceUrl: url.toString());
  }

  /// Split out from the network call so it can be tested against saved HTML.
  static List<Project> parseProjects(String html, {required String sourceUrl}) {
    final blocks = _projectBlocks(html);
    final projects = <Project>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final title = _normalizeText(_stripTags(block.title));
      if (title.isEmpty || title.length > 160) continue;

      final description = _normalizeText(_stripTags(block.body));
      final plain = '$title $description';

      projects.add(Project(
        // Derived from the title so re-importing updates a project instead of
        // creating a second copy of it.
        id: 'w${_slug(title)}',
        title: title,
        description: description.length > 400
            ? '${description.substring(0, 400)}…'
            : description,
        date: DateTime.now().subtract(Duration(days: i)),
        beneficiaries: _beneficiaries(plain),
        location: _location(plain),
        sourceUrl: sourceUrl,
      ));
    }

    return projects;
  }

  /// Candidate project blocks, tried in order of how specific they are.
  static List<({String title, String body})> _projectBlocks(String html) {
    // 1. Containers that name themselves.
    final tagged = RegExp(
      r'<(article|section|div)[^>]*class="[^"]*project[^"]*"[^>]*>(.*?)</\1>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final fromTagged = <({String title, String body})>[];
    for (final match in tagged) {
      final inner = match.group(2) ?? '';
      final heading = RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>',
              caseSensitive: false, dotAll: true)
          .firstMatch(inner);
      if (heading == null) continue;
      final paragraph = RegExp(r'<p[^>]*>(.*?)</p>',
              caseSensitive: false, dotAll: true)
          .firstMatch(inner);
      fromTagged.add((
        title: heading.group(1) ?? '',
        body: paragraph?.group(1) ?? '',
      ));
    }
    if (fromTagged.isNotEmpty) return fromTagged;

    // 2. Otherwise, every sub-heading with the paragraph that follows it.
    final headings = RegExp(r'<h[23][^>]*>(.*?)</h[23]>(.*?)(?=<h[23][^>]*>|$)',
            caseSensitive: false, dotAll: true)
        .allMatches(html);

    final fromHeadings = <({String title, String body})>[];
    for (final match in headings) {
      final following = match.group(2) ?? '';
      final paragraph = RegExp(r'<p[^>]*>(.*?)</p>',
              caseSensitive: false, dotAll: true)
          .firstMatch(following);
      if (paragraph == null) continue;
      fromHeadings.add((
        title: match.group(1) ?? '',
        body: paragraph.group(1) ?? '',
      ));
    }
    return fromHeadings.take(12).toList();
  }

  /// A count stated next to a word meaning "beneficiaries", in any of the
  /// three languages the organisation publishes in. Without the keyword the
  /// number could be anything — a year, a phone number — so a bare number is
  /// never taken.
  static int? _beneficiaries(String text) {
    final match = RegExp(
      r'([\d][\d,.\s]{0,12})\s*(مستفيد\w*|منتفع\w*|beneficiar\w*|begunstig\w*)'
      r'|(?:مستفيد\w*|منتفع\w*|beneficiar\w*|begunstig\w*)[^\d]{0,20}([\d][\d,.\s]{0,12})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final digits = (match.group(1) ?? match.group(3) ?? '')
        .replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits.length > 9) return null;
    return int.tryParse(digits);
  }

  /// A place stated after a word meaning "location".
  static String? _location(String text) {
    final match = RegExp(
      r'(?:الموقع|المكان|المنطقة|location|locatie)\s*[:：-]\s*([^.,;|\n]{2,60})',
      caseSensitive: false,
    ).firstMatch(text);

    final value = _normalizeText(match?.group(1) ?? '');
    return value.isEmpty ? null : value;
  }

  /// A stable, filesystem-and-Firestore-safe id derived from the title.
  static String _slug(String title) {
    final cleaned = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty
        ? '${title.hashCode.abs()}'
        : '${cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned}'
            '-${title.hashCode.abs()}';
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

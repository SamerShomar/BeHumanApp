import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/about/data/website_scraper.dart';
import 'package:be_human_app/features/projects/domain/project.dart';

void main() {
  group('Project.fromJson', () {
    test('reads a complete record', () {
      final project = Project.fromJson({
        'id': 'p1',
        'title': 'Sheikh Radwan water project',
        'description': 'Restoring the water network for 400 households.',
        'date': '2026-08-12T09:00:00.000',
        'beneficiaries': 2400,
        'location': 'Gaza — Sheikh Radwan',
      });

      expect(project, isNotNull);
      expect(project!.beneficiaries, 2400);
      expect(project.location, 'Gaza — Sheikh Radwan');
      expect(project.date.year, 2026);
    });

    test('rejects a record with no id or no title', () {
      expect(Project.fromJson({'title': 'No id'}), isNull);
      expect(Project.fromJson({'id': 'p1', 'title': '   '}), isNull);
    });

    test('keeps a project whose date is unusable, sorting it last', () {
      // Losing a project because someone typed the date wrong would be worse
      // than showing it at the bottom.
      final project = Project.fromJson({
        'id': 'p1',
        'title': 'Winter kits',
        'date': 'last winter',
      });

      expect(project, isNotNull);
      expect(project!.date.millisecondsSinceEpoch, 0);
    });

    test('accepts a beneficiary count written as text', () {
      expect(
        Project.fromJson({'id': 'p1', 'title': 'T', 'beneficiaries': '1,250'})!
            .beneficiaries,
        1250,
      );
      expect(
        Project.fromJson({'id': 'p1', 'title': 'T', 'beneficiaries': 900.0})!
            .beneficiaries,
        900,
      );
    });

    test('treats a missing count as unknown, not as zero', () {
      // "0 beneficiaries" is a claim; a blank field is the absence of one.
      final project = Project.fromJson({'id': 'p1', 'title': 'T'});
      expect(project!.beneficiaries, isNull);
      expect(project.location, isNull);
    });

    test('round-trips', () {
      final original = Project(
        id: 'p1',
        title: 'Water',
        description: 'Short description',
        date: DateTime(2026, 8, 12),
        beneficiaries: 2400,
        location: 'Rafah',
        sourceUrl: 'https://example.org',
      );

      final restored = Project.fromJson(original.toJson())!;
      expect(restored.title, original.title);
      expect(restored.beneficiaries, 2400);
      expect(restored.location, 'Rafah');
      expect(restored.sourceUrl, 'https://example.org');
      expect(restored.date, original.date);
    });
  });

  group('WebsiteScraper.parseProjects', () {
    test('reads projects out of tagged containers', () {
      const html = '''
        <div class="project-card">
          <h3>Sheikh Radwan water project</h3>
          <p>Restoring the network. Location: Gaza. Reached 2,400 beneficiaries.</p>
        </div>
        <div class="project-card">
          <h3>Winter blankets</h3>
          <p>Distribution across Rafah.</p>
        </div>
      ''';

      final projects =
          WebsiteScraper.parseProjects(html, sourceUrl: 'https://example.org');

      expect(projects, hasLength(2));
      expect(projects.first.title, 'Sheikh Radwan water project');
      expect(projects.first.beneficiaries, 2400);
      expect(projects.first.location, 'Gaza');
      expect(projects.first.sourceUrl, 'https://example.org');
      expect(projects[1].beneficiaries, isNull);
    });

    test('falls back to headings followed by a paragraph', () {
      const html = '''
        <h2>Emergency food parcels</h2>
        <p>Delivered weekly. الموقع: خان يونس</p>
        <h2>School rehabilitation</h2>
        <p>Two classrooms rebuilt for 180 مستفيد.</p>
      ''';

      final projects =
          WebsiteScraper.parseProjects(html, sourceUrl: 'https://example.org');

      expect(projects, hasLength(2));
      expect(projects.first.location, 'خان يونس');
      expect(projects[1].beneficiaries, 180);
    });

    test('gives the same project the same id every import', () {
      // Otherwise a second import would duplicate everything instead of
      // updating it.
      const html = '<div class="project"><h3>Water</h3><p>A</p></div>';
      final first = WebsiteScraper.parseProjects(html, sourceUrl: 'https://e.org');
      final second = WebsiteScraper.parseProjects(html, sourceUrl: 'https://e.org');

      expect(first.single.id, second.single.id);
    });

    test('returns nothing rather than nonsense for an unrecognised page', () {
      // The parser was written without access to the live site, so returning
      // an empty list — which the admin screen reports — matters more than
      // guessing.
      expect(
        WebsiteScraper.parseProjects(
          '<html><body><div>no headings here</div></body></html>',
          sourceUrl: 'https://example.org',
        ),
        isEmpty,
      );
    });

    test('never reads a bare number as a beneficiary count', () {
      const html = '<div class="project"><h3>T</h3><p>Founded in 2015.</p></div>';
      expect(
        WebsiteScraper.parseProjects(html, sourceUrl: 'https://e.org')
            .single
            .beneficiaries,
        isNull,
      );
    });
  });

  group('translations', () {
    test('every project key exists in all three languages', () {
      const keys = [
        'latest_projects',
        'no_projects',
        'beneficiaries_count',
        'beneficiaries_label',
        'location_label',
        'add_project',
        'edit_project',
        'import_from_website',
        'projects_imported',
        'projects_import_failed',
      ];

      for (final locale in AppLocalizations.supportedLocales) {
        for (final key in keys) {
          expect(AppLocalizations.translate(locale, key), isNot(key),
              reason: 'Missing "$key" in ${locale.languageCode}');
        }
      }
    });

    test('the beneficiary count substitutes its number', () {
      final text = AppLocalizations.translate(
        const Locale('ar'), 'beneficiaries_count', {'count': '2,400'},
      );
      expect(text, contains('2,400'));
      expect(text, isNot(contains('{count}')));
    });
  });
}

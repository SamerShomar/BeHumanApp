/// One project the foundation has run, as shown on the home screen.
///
/// Projects live in Firestore rather than being scraped on every launch. Three
/// reasons, in order of weight:
///
///  * a phone with no connection still shows them, like everything else in the
///    app — the website cannot be read offline;
///  * everyone sees the same list, instead of only whoever last pressed a
///    refresh button;
///  * a redesign of the website cannot empty the app's home screen.
///
/// The website is still a source: an admin can import from it, and what comes
/// back is written here.
class Project {
  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.beneficiaries,
    this.location,
    this.sourceUrl,
  });

  final String id;
  final String title;

  /// A short paragraph, shown clamped under the title.
  final String description;

  final DateTime date;

  /// How many people the project reached. Null when it was never recorded —
  /// which is different from zero, and is shown as nothing rather than "0".
  final int? beneficiaries;

  /// Where it ran: "Gaza — Sheikh Radwan", "Rafah", and so on.
  final String? location;

  /// The page this was imported from, when it came from the website.
  final String? sourceUrl;

  static Project? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;

    final title = (json['title'] as String? ?? '').trim();
    if (title.isEmpty) return null;

    return Project(
      id: id,
      title: title,
      description: (json['description'] as String? ?? '').trim(),
      // A missing or unreadable date sorts last rather than dropping the
      // project out of the list entirely.
      date: DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      beneficiaries: switch (json['beneficiaries']) {
        final int value => value,
        final num value => value.round(),
        final String value => int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')),
        _ => null,
      },
      location: (json['location'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['location'] as String).trim(),
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        if (beneficiaries != null) 'beneficiaries': beneficiaries,
        if (location != null) 'location': location,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      };
}

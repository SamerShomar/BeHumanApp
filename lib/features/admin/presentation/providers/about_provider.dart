import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutNotifier extends StateNotifier<Map<String, String>> {
  AboutNotifier() : super({
    'mission': '',
    'vision': '',
    'description': '',
  });

  void setAll(Map<String, dynamic>? data, {Function(dynamic error)? error, Function()? loading}) {
    if (data == null) {
      return;
    }
    
    state = {
      'mission': data['mission'] ?? '',
      'vision': data['vision'] ?? '',
      'description': data['description'] ?? '',
    };
  }

  void updateField(String field, String value) {
    state = {...state, field: value};
  }
}

final aboutProvider = StateNotifierProvider<AboutNotifier, Map<String, String>>((ref) {
  return AboutNotifier();
});
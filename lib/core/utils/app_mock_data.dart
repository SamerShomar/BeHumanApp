import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

class AppMockData {
  // Mutable list of users so admin can update roles at runtime
  static List<AppUser> mockUsers = [
    const AppUser(
      uid: '1',
      email: 'admin@behuman.org',
      name: 'Admin Be Human',
      role: UserRole.admin,
      team: UserTeam.netherlands,
    ),
    const AppUser(
      uid: '2',
      email: 'samershomar@behuman.org',
      name: 'Samer Shomar',
      role: UserRole.member,
      team: UserTeam.gaza,
    ),
    const AppUser(
      uid: '3',
      email: 'mahmoudabuaisha@behuman.org',
      name: 'Mahmoud Abu Aisha',
      role: UserRole.member,
      team: UserTeam.gaza,
    ),
    const AppUser(
      uid: '4',
      email: 'lottegraat@behuman.org',
      name: 'Lotte Graat',
      role: UserRole.manager,
      team: UserTeam.netherlands,
    ),
    const AppUser(
      uid: '5',
      email: 'nellie@behuman.org',
      name: 'Nellie',
      role: UserRole.manager,
      team: UserTeam.netherlands,
    ),
    const AppUser(
      uid: '6',
      email: 'foekje@behuman.org',
      name: 'Foekje',
      role: UserRole.manager,
      team: UserTeam.netherlands,
    ),
  ];

  // initial proposals are defined below as a mutable list

  // Mutable finances map so we can update totals at runtime
  static Map<String, double> mockFinances = {
    'totalIncome': 5000.0,
    'totalExpense': 2000.0,
    'balance': 3000.0,
  };

  // Mutable proposals list (can be added/removed at runtime)
  static List<Map<String, dynamic>> mockProposals = [
    {
      'id': 'p1',
      'title': 'سلات غذائية طارئة - شمال غزة',
      'status': 'معلق',
      'date': '2024-05-20',
      'amount': 2500.0,
    },
    {
      'id': 'p2',
      'title': 'ترميم بئر مياه - رفح',
      'status': 'مقبول',
      'date': '2024-05-18',
      'amount': 4800.0,
    },
    {
      'id': 'p3',
      'title': 'كسوة عيد للأيتام',
      'status': 'معلق',
      'date': '2024-05-15',
      'amount': 1200.0,
    },
  ];

  // About data fetched from website (mission, vision, description)
  static String mission = '';
  static String vision = '';
  static String description = '';
}

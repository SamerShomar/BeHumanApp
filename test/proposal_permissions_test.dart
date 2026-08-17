import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/proposals/domain/proposal_permissions.dart';

/// An admin could not remove a proposal once it had been decided.
///
/// The Firestore rules allowed it from the beginning — `allow delete: if
/// isAdmin() || …`. The screen simply never offered the button, checking only
/// whether *you* had submitted it and it was still pending. So an accepted
/// proposal was permanent for everybody, however plainly it needed to go.
void main() {
  const admin = AppUser(
    uid: 'admin-1',
    email: 'samer@behuman.org',
    name: 'Samer',
    role: UserRole.admin,
    team: UserTeam.netherlands,
  );
  const manager = AppUser(
    uid: 'manager-1',
    email: 'foekje@behuman.org',
    name: 'Foekje',
    role: UserRole.manager,
    team: UserTeam.netherlands,
  );
  const submitter = AppUser(
    uid: 'gaza-1',
    email: 'mahmoud@behuman.org',
    name: 'Mahmoud',
    role: UserRole.member,
    team: UserTeam.gaza,
  );

  Map<String, dynamic> proposal(String status, {String by = 'gaza-1'}) =>
      {'id': 'p1', 'status': status, 'submittedBy': by};

  group('an admin', () {
    test('may remove a proposal at any status', () {
      for (final status in ['pending', 'accepted', 'rejected']) {
        expect(
          ProposalPermissions.canDelete(admin, proposal(status)),
          isTrue,
          reason: 'admin blocked on a $status proposal',
        );
      }
    });

    test('may remove one written in the old Arabic labels too', () {
      // Documents created before statuses became stable keys stored the
      // translated word, and those are exactly the oldest records.
      for (final status in ['معلق', 'مقبول', 'مرفوض']) {
        expect(ProposalPermissions.canDelete(admin, proposal(status)), isTrue);
      }
    });

    test('does not need to be the submitter', () {
      expect(
        ProposalPermissions.canDelete(admin, proposal('accepted', by: 'someone')),
        isTrue,
      );
    });
  });

  group('a submitter', () {
    test('may withdraw their own while it is pending', () {
      expect(ProposalPermissions.canDelete(submitter, proposal('pending')), isTrue);
    });

    test('may not once it has been decided', () {
      // It belongs to the record at that point; only an admin takes it out.
      expect(ProposalPermissions.canDelete(submitter, proposal('accepted')), isFalse);
      expect(ProposalPermissions.canDelete(submitter, proposal('rejected')), isFalse);
    });

    test('may not touch somebody else’s', () {
      expect(
        ProposalPermissions.canDelete(submitter, proposal('pending', by: 'gaza-2')),
        isFalse,
      );
    });
  });

  test('a manager who did not submit it cannot delete it', () {
    // Deciding and deleting are different powers. A manager reviews; removing
    // something from the record stays with an admin, matching the rules.
    expect(ProposalPermissions.canDelete(manager, proposal('accepted')), isFalse);
    expect(ProposalPermissions.canDelete(manager, proposal('pending')), isFalse);
  });

  test('nobody signed out can delete anything', () {
    expect(ProposalPermissions.canDelete(null, proposal('pending')), isFalse);
  });

  group('deciding', () {
    test('stays open after a decision, so one can be reversed', () {
      expect(ProposalPermissions.canDecide(admin), isTrue);
      expect(ProposalPermissions.canDecide(manager), isTrue);
    });

    test('is not open to a Gaza member', () {
      expect(ProposalPermissions.canDecide(submitter), isFalse);
    });

    test('is not open to nobody', () {
      expect(ProposalPermissions.canDecide(null), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';

void main() {
  group('ProposalStatus.normalize', () {
    test('passes stable keys through', () {
      expect(ProposalStatus.normalize('pending'), ProposalStatus.pending);
      expect(ProposalStatus.normalize('accepted'), ProposalStatus.accepted);
      expect(ProposalStatus.normalize('rejected'), ProposalStatus.rejected);
    });

    test('understands the Arabic labels written before keys existed', () {
      // Documents created earlier stored the translated word directly, which
      // is why the delete rule and the UI both have to accept them.
      expect(ProposalStatus.normalize('معلق'), ProposalStatus.pending);
      expect(ProposalStatus.normalize('مقبول'), ProposalStatus.accepted);
      expect(ProposalStatus.normalize('مرفوض'), ProposalStatus.rejected);
    });

    test('treats anything unrecognised as pending', () {
      // Pending is the state that grants the fewest rights, so an unreadable
      // value must not be mistaken for an approval.
      expect(ProposalStatus.normalize(null), ProposalStatus.pending);
      expect(ProposalStatus.normalize(''), ProposalStatus.pending);
      expect(ProposalStatus.normalize(42), ProposalStatus.pending);
      expect(ProposalStatus.normalize('something else'), ProposalStatus.pending);
    });

    test('ignores surrounding whitespace', () {
      expect(ProposalStatus.normalize('  accepted '), ProposalStatus.accepted);
    });
  });

  group('ProposalStatus.isPending', () {
    test('gates deletion on the normalized value, not the raw string', () {
      expect(ProposalStatus.isPending('معلق'), isTrue);
      expect(ProposalStatus.isPending('pending'), isTrue);
      expect(ProposalStatus.isPending('accepted'), isFalse);
      expect(ProposalStatus.isPending('مقبول'), isFalse);
    });
  });
}

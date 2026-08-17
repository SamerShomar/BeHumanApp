import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';

/// Who may do what to a proposal.
///
/// Split out of the details dialog so the rule can be read and tested on its
/// own. It mirrors what `firestore.rules` enforces — the server is the actual
/// boundary, and this only decides what is worth showing.
abstract final class ProposalPermissions {
  /// Whether [user] may remove [proposal].
  ///
  /// Two separate permissions:
  ///
  ///  * a submitter may **withdraw their own** proposal while it is still
  ///    pending. Once it has been decided it belongs to the record and is no
  ///    longer theirs to take back.
  ///  * an **admin** may remove any proposal at any status.
  ///
  /// The second one existed in the rules from the start and was never offered
  /// by the screen, which checked only the first — so an accepted proposal
  /// could not be removed by anybody, however plainly it needed to go: a
  /// duplicate, a test entry, a file attached in error.
  static bool canDelete(AppUser? user, Map<String, dynamic> proposal) {
    if (user == null) return false;
    if (user.isAdmin) return true;

    return proposal['submittedBy'] == user.uid &&
        ProposalStatus.isPending(proposal['status']);
  }

  /// Whether [user] may accept or reject [proposal].
  ///
  /// Deliberately not conditional on the current status: a decision that turns
  /// out to be wrong has to be reversible, so an accepted proposal can still
  /// be rejected and the other way round.
  static bool canDecide(AppUser? user) =>
      user != null && (user.team == UserTeam.netherlands || user.isAdmin);
}

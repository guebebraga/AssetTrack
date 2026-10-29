import '../core/utils/ids.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'movement_service.dart';

class LoanResult {
  const LoanResult({
    required this.success,
    required this.message,
    this.loan,
  });

  final bool success;
  final String message;
  final Loan? loan;
}

class LoanService {
  LoanService(this.state, {required this.movementService});

  final AppState state;
  final MovementService movementService;

  LoanResult createLoan({
    required String assetId,
    required String borrower,
    required DateTime deliveredAt,
    DateTime? dueAt,
    String reason = '',
    String notes = '',
    String? accessId,
    String? readerId,
  }) {
    final asset = state.assetById(assetId);
    if (asset == null) {
      return const LoanResult(
        success: false,
        message: 'No se encontró el activo indicado.',
      );
    }
    if (borrower.trim().isEmpty) {
      return const LoanResult(
        success: false,
        message: 'Indicá la persona o entidad que recibe el activo.',
      );
    }
    if (state.openLoanForAsset(assetId) != null) {
      return const LoanResult(
        success: false,
        message: 'El activo ya tiene un préstamo activo.',
      );
    }

    final result = movementService.record(
      assetId: assetId,
      type: MovementType.loan,
      timestamp: deliveredAt,
      origin: EventOrigin.manual,
      accessId: accessId,
      readerId: readerId,
      responsible: borrower.trim(),
      expectedReturnAt: dueAt,
      reason: reason,
      notes: notes,
    );
    if (!result.success) {
      return LoanResult(success: false, message: result.message);
    }

    final loan = Loan(
      id: newId('PRE'),
      assetId: assetId,
      borrower: borrower.trim(),
      deliveredAt: deliveredAt,
      dueAt: dueAt,
      reason: reason,
      notes: notes,
      status: LoanStatus.active,
    );
    state.loans.add(loan);
    return LoanResult(
      success: true,
      message: 'Préstamo registrado correctamente.',
      loan: loan,
    );
  }

  LoanResult returnLoan({
    required String loanId,
    required DateTime returnedAt,
    bool confirmedInside = false,
    bool administrativeCorrection = false,
    String notes = '',
  }) {
    final loan = state.loanById(loanId);
    if (loan == null) {
      return const LoanResult(
        success: false,
        message: 'No se encontró el préstamo.',
      );
    }
    if (!loan.isOpen) {
      return const LoanResult(
        success: false,
        message: 'El préstamo ya fue devuelto.',
      );
    }
    if (!confirmedInside && !administrativeCorrection) {
      return const LoanResult(
        success: false,
        message:
            'El activo todavía no está físicamente dentro. Confirmá el ingreso '
            'o registrá una corrección administrativa explícita.',
      );
    }

    final asset = state.assetById(loan.assetId);
    if (asset == null) {
      return const LoanResult(
        success: false,
        message: 'El activo asociado al préstamo no existe.',
      );
    }

    final result = movementService.record(
      assetId: loan.assetId,
      type: MovementType.loanReturn,
      timestamp: returnedAt,
      origin: administrativeCorrection && !confirmedInside
          ? EventOrigin.correction
          : EventOrigin.manual,
      responsible: loan.borrower,
      reason: loan.reason,
      notes: administrativeCorrection && !confirmedInside
          ? 'Corrección administrativa: devolución registrada sin confirmación '
                'física de ingreso. $notes'
          : notes,
      bypassValidation: administrativeCorrection && !confirmedInside,
      checkDuplicate: false,
    );
    if (!result.success) {
      return LoanResult(success: false, message: result.message);
    }

    final updated = loan.copyWith(
      status: LoanStatus.returned,
      returnedAt: returnedAt,
      returnConfirmedInside: confirmedInside,
      notes: notes.isEmpty ? loan.notes : notes,
    );
    final index = state.loans.indexWhere((item) => item.id == loanId);
    state.loans[index] = updated;
    return LoanResult(
      success: true,
      message: administrativeCorrection && !confirmedInside
          ? 'Devolución registrada por corrección administrativa.'
          : 'Devolución registrada correctamente.',
      loan: updated,
    );
  }

  LoanResult markPendingVerification(String loanId, {String notes = ''}) {
    final loan = state.loanById(loanId);
    if (loan == null || !loan.isOpen) {
      return const LoanResult(
        success: false,
        message: 'El préstamo no está activo.',
      );
    }
    final index = state.loans.indexWhere((item) => item.id == loanId);
    state.loans[index] = loan.copyWith(
      status: LoanStatus.pendingVerification,
      notes: notes,
    );
    return LoanResult(
      success: true,
      message: 'Préstamo marcado como pendiente de verificación.',
      loan: state.loans[index],
    );
  }
}

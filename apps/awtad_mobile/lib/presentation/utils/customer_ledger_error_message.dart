import 'package:awtad_retail/awtad_retail.dart';

import '../../core/database/database_init_exception.dart';

const _duplicateMessage = 'هذا العميل مسجل بالفعل أو الرقم مكرر.';
const _validationMessage = 'البيانات المدخلة غير صحيحة. تحقق من الحقول.';
const _storageMessage =
    'تعذر حفظ العملية في قاعدة البيانات. حاول مرة أخرى.';
const _fallbackMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

String customerLedgerErrorMessage(Object error) {
  if (isDuplicateLikeError(error)) {
    return _duplicateMessage;
  }
  if (isValidationLikeError(error)) {
    return _validationMessage;
  }
  if (isStorageLikeError(error)) {
    return _storageMessage;
  }
  return _fallbackMessage;
}

bool isDuplicateLikeError(Object error) {
  if (error is DuplicateCustomerException ||
      error is DuplicateCustomerPhoneException ||
      error is DuplicateCustomerAccountEntryException ||
      error is DuplicateOpeningBalanceException) {
    return true;
  }
  return matchesErrorText(error, const [
    'duplicate',
    'unique',
    'constraint',
  ]);
}

bool isValidationLikeError(Object error) {
  if (error is ArgumentError ||
      error is FormatException ||
      error is OpeningBalanceNotFirstException ||
      error is InconsistentCurrencyException) {
    return true;
  }
  return matchesErrorText(error, const [
    'validation',
    'argument',
    'invalid',
  ]);
}

bool isStorageLikeError(Object error) {
  if (error is DatabaseInitException) {
    return true;
  }
  return matchesErrorText(error, const [
    'storage',
    'database',
    'sqflite',
    'sqlite',
  ]);
}

bool matchesErrorText(Object error, List<String> needles) {
  final haystack =
      '${error.runtimeType} ${error.toString()}'.toLowerCase();
  for (final needle in needles) {
    if (haystack.contains(needle)) {
      return true;
    }
  }
  return false;
}

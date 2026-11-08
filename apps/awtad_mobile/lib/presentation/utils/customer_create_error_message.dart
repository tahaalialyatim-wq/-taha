import 'customer_ledger_error_message.dart';

const _duplicatePhoneMessage = 'رقم الهاتف مسجل بالفعل لعميل آخر.';
const _validationMessage = 'البيانات المدخلة غير صحيحة. تحقق من الحقول.';
const _storageMessage = 'تعذر حفظ العميل في قاعدة البيانات. حاول مرة أخرى.';
const _fallbackMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

String customerCreateErrorMessage(Object error) {
  if (isDuplicateLikeError(error)) {
    return _duplicatePhoneMessage;
  }
  if (isValidationLikeError(error)) {
    return _validationMessage;
  }
  if (isStorageLikeError(error)) {
    return _storageMessage;
  }
  return _fallbackMessage;
}

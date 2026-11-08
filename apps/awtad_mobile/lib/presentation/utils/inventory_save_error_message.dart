import 'customer_ledger_error_message.dart';

const _priceCurrencyMessage =
    'تحقق من السعر والعملة. لا يسمح بأسعار سالبة.';
const _storageMessage = 'تعذر حفظ المنتج في قاعدة البيانات. حاول مرة أخرى.';
const _fallbackMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

String inventorySaveErrorMessage(Object error) {
  if (_isPriceOrCurrency(error) || isValidationLikeError(error)) {
    return _priceCurrencyMessage;
  }
  if (isStorageLikeError(error)) {
    return _storageMessage;
  }
  return _fallbackMessage;
}

bool _isPriceOrCurrency(Object error) {
  return matchesErrorText(error, const [
    'price',
    'currency',
    'negative',
    'سالب',
  ]);
}

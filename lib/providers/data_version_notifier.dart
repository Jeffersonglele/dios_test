import 'package:flutter/foundation.dart';

final dataVersionNotifier = ValueNotifier<int>(0);

void notifyDataChanged() {
  dataVersionNotifier.value = dataVersionNotifier.value + 1;
}

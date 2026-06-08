import 'package:flutter/foundation.dart';

class SimpleUIController extends ChangeNotifier {
  bool _isObscure = true;
  bool get isObscure => _isObscure;
  set isObscure(bool v) { _isObscure = v; notifyListeners(); }
  void isObscureActive() { _isObscure = !_isObscure; notifyListeners(); }
}

import 'package:get/get.dart';

class SimpleUIController extends GetxController {
  RxBool isObscure = true.obs;

  void isObscureActive() {
    isObscure.value = !isObscure.value;
  }
}

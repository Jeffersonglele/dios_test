import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop dart plugin classes are exported for Flutter registrant', () {
    FilePickerLinux.registerWith();
    expect(FilePicker.platform, isA<FilePickerLinux>());

    FilePickerMacOS.registerWith();
    expect(FilePicker.platform, isA<FilePickerMacOS>());

    FilePickerWindows.registerWith();
    expect(FilePicker.platform, isA<FilePickerWindows>());
  });
}

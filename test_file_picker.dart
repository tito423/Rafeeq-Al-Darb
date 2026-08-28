import 'package:file_picker/file_picker.dart';

void main() async {
  var result = await FilePicker.pickFiles();
  print(result);
}

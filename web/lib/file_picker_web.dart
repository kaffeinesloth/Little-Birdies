// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedKnowledgeFile {
  const PickedKnowledgeFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<PickedKnowledgeFile?> pickKnowledgeFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.txt,.pdf,.docx'
    ..multiple = false;
  final completer = Completer<PickedKnowledgeFile?>();

  input.onChange.first.then((_) {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(
          PickedKnowledgeFile(name: file.name, bytes: result.asUint8List()),
        );
      } else {
        completer.complete(null);
      }
    });
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}

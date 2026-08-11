import 'dart:typed_data';

class PickedKnowledgeFile {
  const PickedKnowledgeFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<PickedKnowledgeFile?> pickKnowledgeFile() async => null;

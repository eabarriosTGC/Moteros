import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final bytes = utf8.encode('Test1234!');
  print('Hash: ${sha256.convert(bytes).toString()}');
}

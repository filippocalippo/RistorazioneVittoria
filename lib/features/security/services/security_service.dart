import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../repositories/security_repository.dart';

class SecurityService {
  final SecurityRepository _repository;

  SecurityService(this._repository);

  // Hashing Utilities
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64Url.encode(values);
  }

  String _hash(String input, String salt) {
    final bytes = utf8.encode(input + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Code Generation
  List<String> generateRecoveryCodes() {
    final random = Random.secure();
    final codes = <String>[];
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, 1, O, 0 to avoid confusion

    for (int i = 0; i < 10; i++) {
      final buffer = StringBuffer();
      for (int j = 0; j < 4; j++) {
        buffer.write(chars[random.nextInt(chars.length)]);
      }
      buffer.write('-');
      for (int j = 0; j < 4; j++) {
        buffer.write(chars[random.nextInt(chars.length)]);
      }
      codes.add(buffer.toString());
    }
    return codes;
  }

  // Core Operations
  Future<bool> verifyPassword(String inputPassword) async {
    final settings = await _repository.getSecuritySettings();
    if (settings == null) return false;

    final salt = settings['salt'] as String;
    final storedHash = settings['password_hash'] as String;
    final inputHash = _hash(inputPassword, salt);

    return inputHash == storedHash;
  }

  Future<bool> verifyRecoveryCode(String code) async {
    final settings = await _repository.getSecuritySettings();
    if (settings == null) return false;

    final salt = settings['salt'] as String;
    final storedHashes = List<String>.from(settings['recovery_hashes'] ?? []);
    final inputHash = _hash(code, salt);

    return storedHashes.contains(inputHash);
  }

  Future<List<String>> setupSecurity(String password) async {
    final salt = _generateSalt();
    final passwordHash = _hash(password, salt);
    final recoveryCodes = generateRecoveryCodes();
    
    final recoveryHashes = recoveryCodes
        .map((code) => _hash(code, salt))
        .toList();

    await _repository.initializeSecurity(
      passwordHash: passwordHash,
      salt: salt,
      recoveryHashes: recoveryHashes,
    );

    return recoveryCodes;
  }

  Future<void> downloadRecoveryCodes(List<String> codes) async {
    final buffer = StringBuffer();
    buffer.writeln('=== CODICI DI RECUPERO ROTANTE ===');
    buffer.writeln('Salva questo file in un luogo sicuro.');
    buffer.writeln('Ogni codice puÃ² essere usato una sola volta per resettare la password.');
    buffer.writeln('-----------------------------------');
    for (final code in codes) {
      buffer.writeln(code);
    }
    buffer.writeln('-----------------------------------');
    buffer.writeln('Generato il: ${DateTime.now().toLocal()}');

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Share sheet (best experience for mobile)
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/codici_recupero_rotante.txt');
        await file.writeAsString(buffer.toString());
        // Note: Share_plus is not imported here anymore, but logic would remain for mobile if needed
        // For now, focusing on the desktop request which was specific about "save to directory"
        throw Exception("Mobile implementation requires Share_plus, but we are switching to FilePicker for Desktop/Web preference.");
      } else {
        // Desktop/Web: Save File Dialog
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Salva Codici di Recupero',
          fileName: 'codici_recupero_rotante.txt',
          type: FileType.custom,
          allowedExtensions: ['txt'],
          bytes: utf8.encode(buffer.toString()),
        );

        if (result == null) {
          // User canceled the picker
          throw Exception('Salvataggio annullato');
        }

        // On desktop saveFile returns path, write manually if needed or handled by bytes
        if (result.isNotEmpty) {
             final file = File(result);
             await file.writeAsString(buffer.toString());
        }
      }
    } catch (e) {
      if (e.toString().contains('annullato')) return; // Ignore cancel
      throw Exception('Impossibile salvare i codici: $e');
    }
  }
}

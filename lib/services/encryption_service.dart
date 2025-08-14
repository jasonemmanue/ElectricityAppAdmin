// Fichier : lib/services/encryption_service.dart
// (CE CODE DOIT ÊTRE IDENTIQUE DANS LES DEUX PROJETS)

import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  // La clé et l'IV doivent être un copier-coller parfait.
  final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows!');
  final _iv = encrypt.IV.fromLength(16);

  late final encrypt.Encrypter _encrypter;

  EncryptionService() {
    _encrypter = encrypt.Encrypter(encrypt.AES(_key));
  }

  String encryptText(String plainText) {
    if (plainText.trim().isEmpty) return '';
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  String decryptText(String encryptedText) {
    if (encryptedText.trim().isEmpty) return '';
    try {
      final encryptedData = encrypt.Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encryptedData, iv: _iv);
    } catch (e) {
      // Cette erreur se produit si le texte n'est pas chiffré.
      print("ERREUR DE DÉCHIFFREMENT : Le message reçu n'était pas chiffré. Erreur: $e");
      return "[Message non chiffré]";
    }
  }
}
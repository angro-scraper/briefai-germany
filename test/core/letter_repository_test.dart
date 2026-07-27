import 'dart:typed_data';

import 'package:briefai_germany/core/app_services.dart';
import 'package:briefai_germany/core/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'legacy account vaults migrate into one durable device-local archive',
    () async {
      final repository = LetterRepository(
        cloudEnabled: false,
        databaseFactory: databaseFactoryMemory,
        databasePath: 'vault-test.db',
      );
      final now = DateTime.utc(2026, 7, 26);
      LetterAnalysis letter(String id, String sourceText) => LetterAnalysis(
        id: id,
        title: 'Test',
        plainExplanation: 'Objašnjenje',
        category: LetterCategory.finanzamt,
        urgency: Urgency.medium,
        suggestedAction: 'Odgovorite.',
        createdAt: now,
        sourceText: sourceText,
      );
      final document = PickedDocument(
        name: 'pismo.pdf',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'application/pdf',
        ocrPath: null,
      );

      await repository.save(
        'user:alice',
        letter('alice-letter', 'Alice OCR'),
        document: document,
      );
      await repository.save(
        'user:bob',
        letter('bob-letter', 'Bob OCR'),
        document: document,
      );

      await repository.migrateToDeviceVault();
      final archive = await repository.exportRecords(
        LetterRepository.deviceVaultKey,
      );
      expect(
        archive.map((record) => record['id']),
        containsAll(['alice-letter', 'bob-letter']),
      );
      expect(
        await repository.loadDocument(
          LetterRepository.deviceVaultKey,
          'alice-letter',
        ),
        isNotNull,
      );

      await repository.clearAll(LetterRepository.deviceVaultKey);
      expect(
        await repository.exportRecords(LetterRepository.deviceVaultKey),
        isEmpty,
      );
    },
  );

  test(
    'migration is idempotent and includes anonymous legacy records',
    () async {
      final repository = LetterRepository(
        cloudEnabled: false,
        databaseFactory: databaseFactoryMemory,
        databasePath: 'legacy-vault-test.db',
      );
      // Saving as anonymous models the destination of ownerless records after
      // migration; signed-in account filters must still exclude it.
      await repository.save(
        'anonymous',
        LetterAnalysis(
          id: 'legacy',
          title: 'Legacy',
          plainExplanation: 'Lokalno',
          category: LetterCategory.other,
          urgency: Urgency.low,
          suggestedAction: 'Proverite.',
          createdAt: DateTime.utc(2026, 7, 26),
        ),
      );

      await repository.migrateToDeviceVault();
      await repository.migrateToDeviceVault();
      expect(
        await repository.exportRecords(LetterRepository.deviceVaultKey),
        hasLength(1),
      );
    },
  );
}

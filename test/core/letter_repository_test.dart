import 'dart:typed_data';

import 'package:briefai_germany/core/app_services.dart';
import 'package:briefai_germany/core/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'local vault isolates, exports and deletes records per account',
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

      final alice = await repository.exportRecords('user:alice');
      final bob = await repository.exportRecords('user:bob');
      expect(alice.single['id'], 'alice-letter');
      expect(alice.single['sourceText'], 'Alice OCR');
      expect(alice.single['documentBase64'], 'AQIDBA==');
      expect(bob.single['id'], 'bob-letter');
      expect(await repository.loadDocument('user:bob', 'alice-letter'), isNull);

      await repository.clearAll('user:alice');
      expect(await repository.exportRecords('user:alice'), isEmpty);
      expect(await repository.exportRecords('user:bob'), hasLength(1));
    },
  );

  test(
    'legacy ownerless records are visible only in anonymous vault',
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

      expect(await repository.exportRecords('anonymous'), hasLength(1));
      expect(await repository.exportRecords('user:alice'), isEmpty);
    },
  );
}

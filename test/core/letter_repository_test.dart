import 'dart:typed_data';

import 'package:briefai_germany/core/app_services.dart';
import 'package:briefai_germany/core/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'legacy device archive is claimed by exactly one signed-in account',
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
        LetterRepository.deviceVaultKey,
        letter('alice-letter', 'Alice OCR'),
        document: document,
      );

      final aliceVault = LetterRepository.userVaultKey('alice');
      final bobVault = LetterRepository.userVaultKey('bob');
      await repository.claimLegacyDeviceVault(aliceVault);
      await repository.claimLegacyDeviceVault(bobVault);

      final archive = await repository.exportRecords(aliceVault);
      expect(archive.map((record) => record['id']), ['alice-letter']);
      expect(await repository.exportRecords(bobVault), isEmpty);
      expect(
        await repository.loadDocument(aliceVault, 'alice-letter'),
        isNotNull,
      );

      await repository.clearAll(aliceVault);
      expect(await repository.exportRecords(aliceVault), isEmpty);
    },
  );

  test(
    'signed-in and anonymous archives stay isolated on one device',
    () async {
      final repository = LetterRepository(
        cloudEnabled: false,
        databaseFactory: databaseFactoryMemory,
        databasePath: 'legacy-vault-test.db',
      );
      await repository.save(
        LetterRepository.anonymousVaultKey,
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
      final signedInVault = LetterRepository.userVaultKey('firebase-uid');
      await repository.save(
        signedInVault,
        LetterAnalysis(
          id: 'signed-in',
          title: 'Privatno',
          plainExplanation: 'Samo za nalog',
          category: LetterCategory.other,
          urgency: Urgency.low,
          suggestedAction: 'Proverite.',
          createdAt: DateTime.utc(2026, 7, 27),
        ),
      );

      expect(
        await repository.exportRecords(LetterRepository.anonymousVaultKey),
        hasLength(1),
      );
      expect(await repository.exportRecords(signedInVault), hasLength(1));
      expect(
        (await repository.exportRecords(signedInVault)).single['id'],
        'signed-in',
      );
    },
  );

  test('all document pages are stored locally and restored in order', () async {
    final repository = LetterRepository(
      cloudEnabled: false,
      databaseFactory: databaseFactoryMemory,
      databasePath: 'multi-page-vault-test.db',
    );
    final pages = <PickedDocument>[
      PickedDocument(
        name: 'page-1.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
        ocrPath: null,
      ),
      PickedDocument(
        name: 'page-2.png',
        bytes: Uint8List.fromList([4, 5, 6, 7]),
        mimeType: 'image/png',
        ocrPath: null,
      ),
      PickedDocument(
        name: 'attachment.pdf',
        bytes: Uint8List.fromList([8, 9]),
        mimeType: 'application/pdf',
        ocrPath: null,
      ),
    ];
    const vault = 'user:multi-page-user';

    await repository.save(
      vault,
      LetterAnalysis(
        id: 'multi-page-letter',
        title: 'Višestranično pismo',
        plainExplanation: 'Objašnjenje',
        category: LetterCategory.other,
        urgency: Urgency.medium,
        suggestedAction: 'Odgovorite.',
        createdAt: DateTime.utc(2026, 8, 14),
        sourceText: 'Strana 1\nStrana 2\nPrilog',
      ),
      documents: pages,
    );

    final restored = await repository.loadDocuments(vault, 'multi-page-letter');
    expect(restored.map((page) => page.name), [
      'page-1.jpg',
      'page-2.png',
      'attachment.pdf',
    ]);
    expect(restored.map((page) => page.mimeType), [
      'image/jpeg',
      'image/png',
      'application/pdf',
    ]);
    expect(restored[0].bytes, orderedEquals([1, 2, 3]));
    expect(restored[1].bytes, orderedEquals([4, 5, 6, 7]));
    expect(restored[2].bytes, orderedEquals([8, 9]));
    expect(
      (await repository.loadDocument(vault, 'multi-page-letter'))?.name,
      'page-1.jpg',
    );
  });
}

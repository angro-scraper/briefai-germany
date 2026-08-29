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
      await repository.save(
        LetterRepository.anonymousVaultKey,
        letter('alice-anonymous-letter', 'Alice anonymous OCR'),
      );

      final aliceVault = LetterRepository.userVaultKey('alice');
      final bobVault = LetterRepository.userVaultKey('bob');
      await repository.claimLegacyDeviceVault(aliceVault);
      await repository.claimLegacyDeviceVault(bobVault);

      final archive = await repository.exportRecords(aliceVault);
      expect(
        archive.map((record) => record['id']),
        unorderedEquals(['alice-letter', 'alice-anonymous-letter']),
      );
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

  test('generated reply is restored only from its account vault', () async {
    final repository = LetterRepository(
      cloudEnabled: false,
      databaseFactory: databaseFactoryMemory,
      databasePath: 'generated-reply-vault-test.db',
    );
    const ownerVault = 'user:reply-owner';
    const otherVault = 'user:another-user';
    await repository.save(
      ownerVault,
      LetterAnalysis(
        id: 'reply-letter',
        title: 'Inkasso odgovor',
        plainExplanation: 'Potrebno je odgovoriti.',
        category: LetterCategory.debtCollection,
        urgency: Urgency.high,
        suggestedAction: 'Pošaljite prigovor.',
        createdAt: DateTime.utc(2026, 8, 14),
        sourceText: 'Inkasso Forderung',
      ),
    );

    final saved = await repository.saveGeneratedReply(
      ownerVault,
      'reply-letter',
      const GeneratedReply(
        letter: 'Sehr geehrte Damen und Herren, ...',
        email: 'Betreff: Widerspruch ...',
      ),
      userContext: 'Deca nisu mogla da nastave trening.',
    );
    expect(saved, isTrue);

    final restored = await repository.loadGeneratedReply(
      ownerVault,
      'reply-letter',
    );
    expect(restored, isNotNull);
    expect(restored!.reply.letter, contains('Sehr geehrte'));
    expect(restored.reply.email, contains('Widerspruch'));
    expect(restored.userContext, contains('trening'));
    expect(
      await repository.loadGeneratedReply(otherVault, 'reply-letter'),
      isNull,
    );
    expect(
      await repository.saveGeneratedReply(
        otherVault,
        'reply-letter',
        const GeneratedReply(letter: 'Other', email: 'Other'),
        userContext: '',
      ),
      isFalse,
    );
  });

  test('organisation and payment status are persisted in the local vault', () async {
    final repository = LetterRepository(
      cloudEnabled: false,
      databaseFactory: databaseFactoryMemory,
      databasePath: 'organisation-vault-test.db',
    );
    const vault = 'user:organiser';
    await repository.save(
      vault,
      LetterAnalysis(
        id: 'invoice',
        title: 'Rechnung',
        plainExplanation: 'Plaćanje.',
        category: LetterCategory.energy,
        urgency: Urgency.medium,
        suggestedAction: 'Platite.',
        createdAt: DateTime.utc(2026, 8, 29),
        isPaymentObligation: true,
      ),
    );
    await repository.updateOrganisation(
      vault,
      'invoice',
      folder: LetterFolder.finance,
      status: LetterStatus.sent,
      tags: const ['struja', 'avgust', 'struja'],
      paymentPaid: true,
    );
    final record = (await repository.watch(vault).first).single;
    expect(record.folder, LetterFolder.finance);
    expect(record.status, LetterStatus.sent);
    expect(record.tags, ['struja', 'avgust']);
    expect(record.paymentPaid, isTrue);
    expect(record.paymentPaidAt, isNotNull);
  });

  test('encrypted backup requires the matching user password', () async {
    final backup = EncryptedBackupService();
    final encrypted = await backup.encrypt(
      payload: {
        'letters': [
          {'id': 'private', 'title': 'Privatno pismo'},
        ],
      },
      passphrase: 'long-local-password',
    );
    final restored = await backup.decrypt(
      encodedBackup: encrypted,
      passphrase: 'long-local-password',
    );
    expect(restored['letters'], isA<List>());
    await expectLater(
      backup.decrypt(encodedBackup: encrypted, passphrase: 'wrong-password'),
      throwsFormatException,
    );
  });
}

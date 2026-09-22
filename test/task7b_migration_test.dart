import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvex/core/database/nuvex_database.dart';
import 'package:nuvex/features/migration/data/migration_database.dart';
import 'package:nuvex/features/migration/models/migration_queue_item.dart';
import 'package:nuvex/features/migration/services/migration_engine.dart';
import 'package:nuvex/features/migration/services/takeout_scanner.dart';
import 'package:nuvex/telegram/telegram_auth_service.dart';
import 'package:nuvex/telegram/telegram_media_service.dart';
import 'package:nuvex/telegram/telegram_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Directory takeoutDir;
  late Database testDb;
  late NuvexDatabase nuvexDb;
  late MigrationDatabase migrationDb;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nuvex_takeout_test_');
    takeoutDir = Directory('${tempDir.path}/Google_Photos');
    await takeoutDir.create(recursive: true);

    // Set up in-memory SQLite database
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    nuvexDb = NuvexDatabase();
    await nuvexDb.initialize(overrideDb: testDb);

    migrationDb = MigrationDatabase(nuvexDatabase: nuvexDb);
    await migrationDb.initialize(overrideDb: testDb);
  });

  tearDown(() async {
    await testDb.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to generate synthetic Takeout test dataset
  Future<Map<String, File>> createSyntheticTakeoutDataset() async {
    final subFolder = Directory('${takeoutDir.path}/Photos from 2024');
    await subFolder.create(recursive: true);

    // 1. Valid JPG photo
    final photo1 = File('${subFolder.path}/photo1.jpg');
    final photo1Bytes = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0xFF,
      0xD9,
    ]);
    await photo1.writeAsBytes(photo1Bytes, flush: true);

    // 2. Google JSON metadata for photo1 (MUST be ignored)
    final photo1Json = File('${subFolder.path}/photo1.jpg.json');
    await photo1Json.writeAsString(
      '{"title": "photo1.jpg", "description": ""}',
      flush: true,
    );

    // 3. Valid PNG photo
    final photo2 = File('${subFolder.path}/photo2.png');
    final photo2Bytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    await photo2.writeAsBytes(photo2Bytes, flush: true);

    // 4. Google supplemental metadata JSON (MUST be ignored)
    final photo2Meta = File(
      '${subFolder.path}/photo2.png.supplemental-metadata.json',
    );
    await photo2Meta.writeAsString('{"geoData": {}}', flush: true);

    // 5. Valid MP4 video
    final video = File('${subFolder.path}/video.mp4');
    final videoBytes = Uint8List.fromList(
      List.generate(1024, (i) => (i * 3) % 256),
    );
    await video.writeAsBytes(videoBytes, flush: true);

    // 6. Duplicate of photo1 (exact byte-for-byte clone with different filename)
    final duplicate = File('${subFolder.path}/duplicate_of_photo1.jpg');
    await duplicate.writeAsBytes(photo1Bytes, flush: true);

    // 7. General document file
    final notes = File('${subFolder.path}/notes.txt');
    await notes.writeAsString('Nuvex migration notes', flush: true);

    // 8. OS system artifact (MUST be ignored)
    final thumbsDb = File('${subFolder.path}/Thumbs.db');
    await thumbsDb.writeAsBytes([0x00, 0x01, 0x02], flush: true);

    return {
      'photo1': photo1,
      'photo1Json': photo1Json,
      'photo2': photo2,
      'photo2Meta': photo2Meta,
      'video': video,
      'duplicate': duplicate,
      'notes': notes,
      'thumbsDb': thumbsDb,
    };
  }

  group('Task 7B — Google Takeout Scanner', () {
    test(
      'Scans directory recursively, filtering metadata JSON and system files',
      () async {
        await createSyntheticTakeoutDataset();
        const scanner = TakeoutScanner();

        final scanned = await scanner.scanDirectory(takeoutDir);

        // Should contain exactly 5 real media/document items:
        // photo1.jpg, photo2.png, video.mp4, duplicate_of_photo1.jpg, notes.txt
        expect(scanned.length, equals(5));

        final filenames = scanned.map((e) => e.fileName).toSet();
        expect(filenames, contains('photo1.jpg'));
        expect(filenames, contains('photo2.png'));
        expect(filenames, contains('video.mp4'));
        expect(filenames, contains('duplicate_of_photo1.jpg'));
        expect(filenames, contains('notes.txt'));

        // Verify ignored files are NOT present
        expect(filenames.contains('photo1.jpg.json'), isFalse);
        expect(
          filenames.contains('photo2.png.supplemental-metadata.json'),
          isFalse,
        );
        expect(filenames.contains('Thumbs.db'), isFalse);

        // Verify categories and MIME types
        final photoItem = scanned.firstWhere((e) => e.fileName == 'photo1.jpg');
        expect(photoItem.mimeType, equals('image/jpeg'));
        expect(photoItem.category, equals('photos'));

        final videoItem = scanned.firstWhere((e) => e.fileName == 'video.mp4');
        expect(videoItem.mimeType, equals('video/mp4'));
        expect(videoItem.category, equals('videos'));

        final notesItem = scanned.firstWhere((e) => e.fileName == 'notes.txt');
        expect(notesItem.mimeType, equals('text/plain'));
        expect(notesItem.category, equals('documents'));
      },
    );

    test(
      'Computes identical SHA-256 for duplicate file across different paths',
      () async {
        final dataset = await createSyntheticTakeoutDataset();
        const scanner = TakeoutScanner();

        final hash1 = await scanner.computeFileSha256(dataset['photo1']!);
        final hashDup = await scanner.computeFileSha256(dataset['duplicate']!);

        expect(hash1, isNotNull);
        expect(hashDup, isNotNull);
        expect(hash1, equals(hashDup));
      },
    );

    test('Never modifies or deletes source files during scanning', () async {
      final dataset = await createSyntheticTakeoutDataset();
      final originalHash = sha256
          .convert(dataset['photo1']!.readAsBytesSync())
          .toString();

      const scanner = TakeoutScanner();
      await scanner.scanDirectory(takeoutDir);

      // Verify source file exists and hash remains identical
      expect(dataset['photo1']!.existsSync(), isTrue);
      final postScanHash = sha256
          .convert(dataset['photo1']!.readAsBytesSync())
          .toString();
      expect(postScanHash, equals(originalHash));
    });
  });

  group('Task 7B — Dedicated Migration Database & Deduplication', () {
    test(
      'Persists queue items with stable telegramRandomId and SHA-256',
      () async {
        final item = MigrationQueueItem.create(
          localPath: '/data/takeout/pic.jpg',
          fileName: 'pic.jpg',
          sizeBytes: 5000,
          sha256: 'abc123hash',
          mimeType: 'image/jpeg',
          category: 'photos',
        );

        final persisted = await migrationDb.enqueueItem(item);
        expect(persisted.id, isNotNull);
        expect(persisted.telegramRandomId, greaterThan(0));

        final retrieved = await migrationDb.getItemById(persisted.id!);
        expect(retrieved, isNotNull);
        expect(
          retrieved!.localPath,
          equals(p.normalize('/data/takeout/pic.jpg')),
        );
        expect(retrieved.telegramRandomId, equals(persisted.telegramRandomId));
        expect(retrieved.status, equals(MigrationItemStatus.pending));
      },
    );

    test(
      'Enforces cross-path deduplication: duplicate content is marked SKIPPED',
      () async {
        const hash = 'duplicate_sha256_123';

        // 1. Enqueue original
        final original = MigrationQueueItem.create(
          localPath: '/takeout/original.jpg',
          fileName: 'original.jpg',
          sizeBytes: 1000,
          sha256: hash,
          mimeType: 'image/jpeg',
          category: 'photos',
        );
        final savedOriginal = await migrationDb.enqueueItem(original);

        // Simulate original uploaded to Telegram
        await migrationDb.markUploaded(
          savedOriginal.id!,
          messageId: 5001,
          fileId: 9001,
        );

        // 2. Enqueue duplicate at a completely different path with identical SHA-256
        final duplicate = MigrationQueueItem.create(
          localPath: '/takeout/folder2/copy_of_pic.jpg',
          fileName: 'copy_of_pic.jpg',
          sizeBytes: 1000,
          sha256: hash,
          mimeType: 'image/jpeg',
          category: 'photos',
        );
        final savedDuplicate = await migrationDb.enqueueItem(duplicate);

        // Database layer MUST detect that identical content is already uploaded and mark as SKIPPED
        expect(savedDuplicate.status, equals(MigrationItemStatus.skipped));
        expect(savedDuplicate.telegramMessageId, equals(5001));
        expect(savedDuplicate.telegramFileId, equals(9001));
        expect(
          savedDuplicate.errorMessage,
          contains('Duplicate of ${p.normalize('/takeout/original.jpg')}'),
        );
      },
    );

    test('resetStaleUploadingToPending recovers interrupted items while preserving stable randomId', () async {
      final item = MigrationQueueItem.create(
        localPath: '/takeout/large_video.mp4',
        fileName: 'large_video.mp4',
        sizeBytes: 20000000,
        sha256: 'vid_hash_999',
        mimeType: 'video/mp4',
        category: 'videos',
      );
      final saved = await migrationDb.enqueueItem(item);
      final stableRandomId = saved.telegramRandomId;

      // Simulate upload started
      await migrationDb.markUploading(saved.id!);

      final uploadingItem = await migrationDb.getItemById(saved.id!);
      expect(uploadingItem!.status, equals(MigrationItemStatus.uploading));

      // Simulate app crash / restart recovery
      final recoveredCount = await migrationDb.resetStaleUploadingToPending();
      expect(recoveredCount, equals(1));

      final recoveredItem = await migrationDb.getItemById(saved.id!);
      expect(recoveredItem!.status, equals(MigrationItemStatus.pending));
      // CRITICAL: Stable random ID must NOT change across recovery
      expect(recoveredItem.telegramRandomId, equals(stableRandomId));
    });
  });

  group('Task 7B — Resumable Migration Engine & Crash Safety', () {
    test('Uploads queued items and cleanly isolates migration_queue from gallery records', () async {
      await createSyntheticTakeoutDataset();
      final fakeMediaService = MockTelegramMediaService();

      final engine = MigrationEngine(
        migrationDatabase: migrationDb,
        mediaService: fakeMediaService,
        nuvexDatabase: nuvexDb,
      );

      // 1. Scan and stage in queue
      final enqueued = await engine.scanAndEnqueue(takeoutDir);
      expect(enqueued.length, equals(5));

      // Before migration: gallery remote_files MUST be completely empty
      final galleryBefore = await nuvexDb.getRecentMedia();
      expect(galleryBefore, isEmpty);

      // 2. Run migration
      final progress = await engine.startMigration();
      expect(progress.uploadedCount, equals(4)); // 4 unique files
      expect(progress.skippedCount, equals(1)); // 1 duplicate skipped
      expect(progress.failedCount, equals(0));

      // After successful migration: gallery records are created ONLY for confirmed uploads
      final galleryAfter = await nuvexDb.getRecentMedia();
      expect(galleryAfter.length, equals(4));
    });

    test('Crash Window Simulation: reuses stable randomId and prevents duplicate Telegram messages', () async {
      final subFolder = Directory('${takeoutDir.path}/Photos from 2024');
      await subFolder.create(recursive: true);
      final sampleFile = File('${subFolder.path}/crash_test.jpg');
      await sampleFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9], flush: true);

      final crashMediaService = CrashSimulatingMediaService();
      final engine = MigrationEngine(
        migrationDatabase: migrationDb,
        mediaService: crashMediaService,
        nuvexDatabase: nuvexDb,
      );

      await engine.scanAndEnqueue(takeoutDir);

      // Step 1: Trigger first migration attempt where crash occurs immediately after Telegram upload
      crashMediaService.simulateCrashAfterTelegramAccept = true;

      await expectLater(
        engine.startMigration(),
        throwsA(isA<SimulatedProcessCrashException>()),
      );

      // Verify Telegram received the upload with randomId R1
      expect(crashMediaService.recordedTelegramRandomIds.length, equals(1));
      final randomIdUsedInAttempt1 =
          crashMediaService.recordedTelegramRandomIds.first;

      // Item in DB is currently left in 'uploading' state due to simulated crash
      final queueSummary = await migrationDb.getQueueSummary();
      expect(queueSummary['uploading'], equals(1));

      // Step 2: Restart engine / process recovery
      crashMediaService.simulateCrashAfterTelegramAccept = false;

      final resumeEngine = MigrationEngine(
        migrationDatabase: migrationDb,
        mediaService: crashMediaService,
        nuvexDatabase: nuvexDb,
      );

      // Run resumed migration
      final resumeProgress = await resumeEngine.startMigration();
      expect(resumeProgress.uploadedCount, equals(1));

      // Step 3: CRITICAL ASSERTIONS
      // 1. The retry MUST have reused the exact same stable randomId
      expect(crashMediaService.recordedTelegramRandomIds.length, equals(2));
      expect(
        crashMediaService.recordedTelegramRandomIds[1],
        equals(randomIdUsedInAttempt1),
      );

      // 2. Telegram message ID remains deduplicated and item marked as UPLOADED
      final item = await migrationDb.getItemByPath(sampleFile.path);
      expect(item!.status, equals(MigrationItemStatus.uploaded));
      expect(item.telegramMessageId, equals(7771));
    });

    test(
      'Retries transient failures with safe backoff up to max retries',
      () async {
        final subFolder = Directory('${takeoutDir.path}/Photos from 2024');
        await subFolder.create(recursive: true);
        final flakyFile = File('${subFolder.path}/flaky.jpg');
        await flakyFile.writeAsBytes([1, 2, 3, 4], flush: true);

        final flakyMediaService = FlakyMediaService(failCountBeforeSuccess: 2);
        final engine = MigrationEngine(
          migrationDatabase: migrationDb,
          mediaService: flakyMediaService,
          nuvexDatabase: nuvexDb,
        );

        await engine.scanAndEnqueue(takeoutDir);

        final progress = await engine.startMigration(maxRetries: 3);
        expect(progress.uploadedCount, equals(1));
        expect(progress.failedCount, equals(0));

        final item = await migrationDb.getItemByPath(flakyFile.path);
        expect(item!.status, equals(MigrationItemStatus.uploaded));
        expect(item.retryCount, equals(2));
      },
    );

    test(
      'Marks item as FAILED when exceeding max retries without crashing engine',
      () async {
        final subFolder = Directory('${takeoutDir.path}/Photos from 2024');
        await subFolder.create(recursive: true);
        final failedFile = File('${subFolder.path}/permanent_fail.jpg');
        await failedFile.writeAsBytes([1, 2, 3, 4], flush: true);

        final flakyMediaService = FlakyMediaService(failCountBeforeSuccess: 99);
        final engine = MigrationEngine(
          migrationDatabase: migrationDb,
          mediaService: flakyMediaService,
          nuvexDatabase: nuvexDb,
        );

        await engine.scanAndEnqueue(takeoutDir);

        final progress = await engine.startMigration(maxRetries: 2);
        expect(progress.uploadedCount, equals(0));
        expect(progress.failedCount, equals(1));

        final item = await migrationDb.getItemByPath(failedFile.path);
        expect(item!.status, equals(MigrationItemStatus.failed));
        expect(item.retryCount, equals(2));
        expect(item.errorMessage, contains('Simulated network drop'));
      },
    );
  });
}

/// Mock TelegramMediaService for standard migration testing
class MockTelegramMediaService extends TelegramMediaService {
  int _messageCounter = 1000;
  final Set<String> uploadedHashes = {};

  MockTelegramMediaService() : super(authService: TelegramAuthService.create());

  @override
  Future<TelegramUploadResult> uploadDocumentFile({
    required File file,
    String? mimeType,
    void Function(double progress)? onProgress,
    TelegramUploadCancelToken? cancelToken,
    int? randomId,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    cancelToken?.throwIfCancelled();
    onProgress?.call(0.5);
    onProgress?.call(1.0);

    final msgId = ++_messageCounter;
    final fileName = p.basename(file.path);
    final resolvedMime = mimeType ?? 'application/octet-stream';
    final category = resolvedMime.startsWith('video/') ? 'videos' : 'photos';

    return TelegramUploadResult(
      messageId: msgId,
      fileId: msgId * 10,
      accessHash: 1234567,
      fileReference: Uint8List.fromList([1, 2, 3]),
      fileName: fileName,
      mimeType: resolvedMime,
      sizeBytes: file.lengthSync(),
      date: DateTime.now(),
      category: category,
      randomId: randomId,
    );
  }
}

class SimulatedProcessCrashException implements Exception {
  final String message;
  const SimulatedProcessCrashException(this.message);
  @override
  String toString() => 'SimulatedProcessCrashException: $message';
}

/// Service simulating a crash after Telegram MTProto accepted the upload
class CrashSimulatingMediaService extends TelegramMediaService {
  bool simulateCrashAfterTelegramAccept = false;
  final List<int> recordedTelegramRandomIds = [];

  CrashSimulatingMediaService()
    : super(authService: TelegramAuthService.create());

  @override
  Future<TelegramUploadResult> uploadDocumentFile({
    required File file,
    String? mimeType,
    void Function(double progress)? onProgress,
    TelegramUploadCancelToken? cancelToken,
    int? randomId,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (randomId != null) {
      recordedTelegramRandomIds.add(randomId);
    }

    if (simulateCrashAfterTelegramAccept) {
      // Simulate crash right after Telegram accepted the message
      throw const SimulatedProcessCrashException(
        'Process crash after Telegram upload confirmation but before DB write',
      );
    }

    return TelegramUploadResult(
      messageId: 7771,
      fileId: 8881,
      accessHash: 9991,
      fileReference: Uint8List.fromList([7, 8, 9]),
      fileName: p.basename(file.path),
      mimeType: mimeType ?? 'image/jpeg',
      sizeBytes: file.lengthSync(),
      date: DateTime.now(),
      category: 'photos',
      randomId: randomId,
    );
  }
}

/// Service simulating transient network failures before succeeding
class FlakyMediaService extends TelegramMediaService {
  final int failCountBeforeSuccess;
  int _failuresSeen = 0;

  FlakyMediaService({required this.failCountBeforeSuccess})
    : super(authService: TelegramAuthService.create());

  @override
  Future<TelegramUploadResult> uploadDocumentFile({
    required File file,
    String? mimeType,
    void Function(double progress)? onProgress,
    TelegramUploadCancelToken? cancelToken,
    int? randomId,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (_failuresSeen < failCountBeforeSuccess) {
      _failuresSeen++;
      throw const SocketException(
        'Simulated network drop: connection timed out',
      );
    }

    return TelegramUploadResult(
      messageId: 3333,
      fileId: 4444,
      accessHash: 5555,
      fileReference: Uint8List.fromList([4, 5, 6]),
      fileName: p.basename(file.path),
      mimeType: mimeType ?? 'image/jpeg',
      sizeBytes: file.lengthSync(),
      date: DateTime.now(),
      category: 'photos',
      randomId: randomId,
    );
  }
}

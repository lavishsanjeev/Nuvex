import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvex/core/database/nuvex_database.dart';
import 'package:nuvex/telegram/telegram_media_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:t/t.dart' as t;

// ── Test Helper Message Factories ──

t.Message createPhotoMessage({
  required int id,
  required int photoId,
  int width = 1920,
  int height = 1080,
  int size = 500000,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 3, 15, 12, 0, 0);
  return t.Message(
    id: id,
    date: d,
    message: '',
    out: true,
    mentioned: false,
    mediaUnread: false,
    silent: false,
    post: false,
    fromScheduled: false,
    legacy: false,
    editHide: false,
    pinned: false,
    noforwards: false,
    invertMedia: false,
    offline: false,
    videoProcessingPending: false,
    paidSuggestedPostStars: false,
    paidSuggestedPostTon: false,
    peerId: const t.PeerUser(userId: 123456),
    media: t.MessageMediaPhoto(
      spoiler: false,
      livePhoto: false,
      photo: t.Photo(
        hasStickers: false,
        id: photoId,
        accessHash: 987654321,
        fileReference: Uint8List.fromList([1, 2, 3]),
        date: d,
        sizes: [
          t.PhotoSize(type: 's', w: 90, h: 60, size: 5000),
          t.PhotoSize(type: 'm', w: 320, h: 180, size: 25000),
          t.PhotoSize(type: 'x', w: width, h: height, size: size),
        ],
        dcId: 2,
      ),
    ),
  );
}

t.Message createDocumentMessage({
  required int id,
  required int documentId,
  required String fileName,
  required String mimeType,
  required int size,
  List<t.DocumentAttributeBase>? attributes,
  List<t.PhotoSizeBase>? thumbs,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 3, 15, 12, 0, 0);
  final attrs = attributes ?? [t.DocumentAttributeFilename(fileName: fileName)];
  return t.Message(
    id: id,
    date: d,
    message: '',
    out: true,
    mentioned: false,
    mediaUnread: false,
    silent: false,
    post: false,
    fromScheduled: false,
    legacy: false,
    editHide: false,
    pinned: false,
    noforwards: false,
    invertMedia: false,
    offline: false,
    videoProcessingPending: false,
    paidSuggestedPostStars: false,
    paidSuggestedPostTon: false,
    peerId: const t.PeerUser(userId: 123456),
    media: t.MessageMediaDocument(
      nopremium: false,
      spoiler: false,
      video: false,
      round: false,
      voice: false,
      document: t.Document(
        id: documentId,
        accessHash: 11223344,
        fileReference: Uint8List.fromList([4, 5, 6]),
        date: d,
        mimeType: mimeType,
        size: size,
        thumbs: thumbs,
        dcId: 2,
        attributes: attrs,
      ),
    ),
  );
}

t.Message createUnsupportedMessage({required int id}) {
  return t.Message(
    id: id,
    date: DateTime(2026, 3, 15, 12, 0, 0),
    message: 'Unsupported message',
    out: false,
    mentioned: false,
    mediaUnread: false,
    silent: false,
    post: false,
    fromScheduled: false,
    legacy: false,
    editHide: false,
    pinned: false,
    noforwards: false,
    invertMedia: false,
    offline: false,
    videoProcessingPending: false,
    paidSuggestedPostStars: false,
    paidSuggestedPostTon: false,
    peerId: const t.PeerUser(userId: 123456),
    media: const t.MessageMediaUnsupported(),
  );
}

t.Message createEmptyDocumentMessage({required int id}) {
  return t.Message(
    id: id,
    date: DateTime(2026, 3, 15, 12, 0, 0),
    message: 'Empty doc message',
    out: false,
    mentioned: false,
    mediaUnread: false,
    silent: false,
    post: false,
    fromScheduled: false,
    legacy: false,
    editHide: false,
    pinned: false,
    noforwards: false,
    invertMedia: false,
    offline: false,
    videoProcessingPending: false,
    paidSuggestedPostStars: false,
    paidSuggestedPostTon: false,
    peerId: const t.PeerUser(userId: 123456),
    media: const t.MessageMediaDocument(
      nopremium: false,
      spoiler: false,
      video: false,
      round: false,
      voice: false,
      document: t.DocumentEmpty(id: 0),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late TelegramMediaService mediaService;
  late NuvexDatabase database;
  late Database testDb;

  setUp(() async {
    mediaService = TelegramMediaService();
    database = NuvexDatabase();
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.initialize(overrideDb: testDb);
  });

  tearDown(() async {
    await database.close();
  });

  group('Task 7C — Telegram Message Scanning & RemoteFile Mapping', () {
    test(
      '1. Normal Telegram photo message parses and classifies as photos',
      () {
        final msg = createPhotoMessage(
          id: 101,
          photoId: 555001,
          width: 1920,
          height: 1080,
          size: 450000,
        );

        final file = mediaService.normalizeMessage(msg);
        expect(file, isNotNull);
        expect(file!.id, 101);
        expect(file.telegramMessageId, 101);
        expect(file.telegramFileId, 555001);
        expect(file.category, 'photos');
        expect(file.mimeType, 'image/jpeg');
        expect(file.name, 'Photo_101.jpg');
        expect(file.width, 1920);
        expect(file.height, 1080);
        expect(file.sizeBytes, 450000);
        expect(file.localPath, isNull, reason: 'Must NOT download full file');
      },
    );

    test('2. JPEG document message parses, extracts dimensions, and classifies as photos', () {
      final msg = createDocumentMessage(
        id: 201,
        documentId: 666001,
        fileName: 'original_camera_raw.jpg',
        mimeType: 'image/jpeg',
        size: 3500000,
        attributes: [
          const t.DocumentAttributeFilename(
            fileName: 'original_camera_raw.jpg',
          ),
          const t.DocumentAttributeImageSize(w: 4032, h: 3024),
        ],
      );

      final file = mediaService.normalizeMessage(msg);
      expect(file, isNotNull);
      expect(file!.id, 201);
      expect(file.telegramMessageId, 201);
      expect(file.telegramFileId, 666001);
      expect(
        file.category,
        'photos',
        reason: 'Image document must appear in photos',
      );
      expect(file.name, 'original_camera_raw.jpg');
      expect(file.mimeType, 'image/jpeg');
      expect(file.width, 4032);
      expect(file.height, 3024);
      expect(file.sizeBytes, 3500000);
      expect(file.localPath, isNull);
    });

    test('3. PNG document message parses, infers MIME if generic, and classifies as photos', () {
      // Test with application/octet-stream to ensure extension-based inference works
      final msg = createDocumentMessage(
        id: 301,
        documentId: 666002,
        fileName: 'vector_design.PNG',
        mimeType: 'application/octet-stream',
        size: 1800000,
        attributes: [
          const t.DocumentAttributeFilename(fileName: 'vector_design.PNG'),
          const t.DocumentAttributeImageSize(w: 1080, h: 2400),
        ],
      );

      final file = mediaService.normalizeMessage(msg);
      expect(file, isNotNull);
      expect(file!.id, 301);
      expect(file.category, 'photos');
      expect(file.name, 'vector_design.PNG');
      expect(
        file.mimeType,
        'image/png',
        reason: 'MIME must be inferred from .PNG',
      );
      expect(file.width, 1080);
      expect(file.height, 2400);
      expect(file.sizeBytes, 1800000);
    });

    test('4. MP4 document message parses, extracts video attributes, and classifies as videos', () {
      final msg = createDocumentMessage(
        id: 401,
        documentId: 666003,
        fileName: 'drone_footage.mp4',
        mimeType: 'video/mp4',
        size: 15000000,
        attributes: [
          const t.DocumentAttributeFilename(fileName: 'drone_footage.mp4'),
          const t.DocumentAttributeVideo(
            roundMessage: false,
            supportsStreaming: true,
            nosound: false,
            duration: 42.5,
            w: 1280,
            h: 720,
          ),
        ],
      );

      final file = mediaService.normalizeMessage(msg);
      expect(file, isNotNull);
      expect(file!.id, 401);
      expect(file.category, 'videos');
      expect(file.name, 'drone_footage.mp4');
      expect(file.mimeType, 'video/mp4');
      expect(
        file.durationMs,
        42500,
        reason: 'Duration 42.5s converted to 42500ms',
      );
      expect(file.width, 1280);
      expect(file.height, 720);
      expect(file.isVideo, isTrue);
    });

    test('5. Ordinary PDF document parses and classifies as documents', () {
      final msg = createDocumentMessage(
        id: 501,
        documentId: 666004,
        fileName: 'annual_report.pdf',
        mimeType: 'application/pdf',
        size: 750000,
      );

      final file = mediaService.normalizeMessage(msg);
      expect(file, isNotNull);
      expect(file!.id, 501);
      expect(file.category, 'documents');
      expect(file.name, 'annual_report.pdf');
      expect(file.mimeType, 'application/pdf');
      expect(file.sizeBytes, 750000);
      expect(file.isPhoto, isFalse);
      expect(file.isVideo, isFalse);
    });

    test('6. Layer-specific document attributes are parsed seamlessly', () {
      final msg = createDocumentMessage(
        id: 601,
        documentId: 666005,
        fileName: 'old_layer.jpg',
        mimeType: 'image/jpeg',
        size: 200000,
        attributes: [
          const t.DocumentAttributeFilename023(fileName: 'old_layer.jpg'),
          const t.DocumentAttributeImageSize023(w: 800, h: 600),
        ],
      );

      final file = mediaService.normalizeMessage(msg);
      expect(file, isNotNull);
      expect(file!.name, 'old_layer.jpg');
      expect(file.width, 800);
      expect(file.height, 600);
      expect(file.category, 'photos');
    });

    test('7. Unsupported documents and empty media are handled safely', () {
      // Unsupported media
      final unsupported = createUnsupportedMessage(id: 701);
      expect(mediaService.normalizeMessage(unsupported), isNull);

      // Empty document
      final emptyDoc = createEmptyDocumentMessage(id: 702);
      expect(mediaService.normalizeMessage(emptyDoc), isNull);

      // Null media message
      final nullMedia = t.Message(
        id: 703,
        date: DateTime.now(),
        message: 'No media text',
        out: false,
        mentioned: false,
        mediaUnread: false,
        silent: false,
        post: false,
        fromScheduled: false,
        legacy: false,
        editHide: false,
        pinned: false,
        noforwards: false,
        invertMedia: false,
        offline: false,
        videoProcessingPending: false,
        paidSuggestedPostStars: false,
        paidSuggestedPostTon: false,
        peerId: const t.PeerUser(userId: 123456),
      );
      expect(mediaService.normalizeMessage(nullMedia), isNull);
    });
  });

  group('Task 7C — Deduplication & SQLite Integration', () {
    test('Duplicate scan does not create duplicate DB rows and preserves downloaded localPath', () async {
      final msg1 = createPhotoMessage(id: 1001, photoId: 7001);
      final msg2 = createDocumentMessage(
        id: 1002,
        documentId: 7002,
        fileName: 'scanned_image.jpg',
        mimeType: 'image/jpeg',
        size: 120000,
      );
      final msg3 = createDocumentMessage(
        id: 1003,
        documentId: 7003,
        fileName: 'presentation.pdf',
        mimeType: 'application/pdf',
        size: 500000,
      );

      final filesPass1 = [
        mediaService.normalizeMessage(msg1)!,
        mediaService.normalizeMessage(msg2)!,
        mediaService.normalizeMessage(msg3)!,
      ];

      // 1. Initial sync
      await database.upsertFiles(filesPass1);

      var recent = await database.getRecentMedia(limit: 50);
      var docs = await database.getFilesByCategory('documents');
      expect(recent.length, 2, reason: 'photo + scanned_image in recent');
      expect(docs.length, 1, reason: 'presentation.pdf in documents');

      // 2. User downloads the scanned image and favorites it
      final downloadedItem = filesPass1[1].copyWith(
        localPath: '/storage/nuvex_media/1002_scanned_image.jpg',
        isFavorite: true,
      );
      await database.upsertFiles([downloadedItem]);

      // Verify state
      var stored = (await database.getRecentMedia()).firstWhere(
        (f) => f.id == 1002,
      );
      expect(stored.localPath, '/storage/nuvex_media/1002_scanned_image.jpg');
      expect(stored.isFavorite, isTrue);

      // 3. Second sync: re-scanning exact same messages from Telegram
      // (where localPath is null and isFavorite is false)
      final filesPass2 = [
        mediaService.normalizeMessage(msg1)!,
        mediaService.normalizeMessage(msg2)!,
        mediaService.normalizeMessage(msg3)!,
      ];
      await database.upsertFiles(filesPass2);

      // Verify no duplicate rows
      recent = await database.getRecentMedia(limit: 50);
      docs = await database.getFilesByCategory('documents');
      expect(recent.length, 2, reason: 'No duplicates created');
      expect(docs.length, 1, reason: 'No duplicates created');

      // Verify localPath and isFavorite were preserved across sync
      stored = (await database.getRecentMedia()).firstWhere(
        (f) => f.id == 1002,
      );
      expect(
        stored.localPath,
        '/storage/nuvex_media/1002_scanned_image.jpg',
        reason: 'localPath must be preserved across re-sync',
      );
      expect(
        stored.isFavorite,
        isTrue,
        reason: 'isFavorite must be preserved across re-sync',
      );
    });

    test(
      'Collection and Recent queries correctly partition media types',
      () async {
        final photo = mediaService.normalizeMessage(
          createPhotoMessage(id: 2001, photoId: 8001),
        )!;
        final jpgDoc = mediaService.normalizeMessage(
          createDocumentMessage(
            id: 2002,
            documentId: 8002,
            fileName: 'camera_doc.jpg',
            mimeType: 'image/jpeg',
            size: 2000000,
          ),
        )!;
        final pngDoc = mediaService.normalizeMessage(
          createDocumentMessage(
            id: 2003,
            documentId: 8003,
            fileName: 'graphic.png',
            mimeType: 'image/png',
            size: 1000000,
          ),
        )!;
        final mp4Doc = mediaService.normalizeMessage(
          createDocumentMessage(
            id: 2004,
            documentId: 8004,
            fileName: 'reel.mp4',
            mimeType: 'video/mp4',
            size: 8000000,
            attributes: [
              const t.DocumentAttributeVideo(
                roundMessage: false,
                supportsStreaming: true,
                nosound: false,
                duration: 15.0,
                w: 720,
                h: 1280,
              ),
            ],
          ),
        )!;
        final pdfDoc = mediaService.normalizeMessage(
          createDocumentMessage(
            id: 2005,
            documentId: 8005,
            fileName: 'invoice.pdf',
            mimeType: 'application/pdf',
            size: 300000,
          ),
        )!;

        await database.upsertFiles([photo, jpgDoc, pngDoc, mp4Doc, pdfDoc]);

        // Recent media (Photos tab) should contain photos and videos, but NOT PDF documents
        final recent = await database.getRecentMedia();
        expect(recent.length, 4);
        final recentIds = recent.map((f) => f.id).toSet();
        expect(recentIds, containsAll([2001, 2002, 2003, 2004]));
        expect(recentIds, isNot(contains(2005)));

        // Photos collection
        final photos = await database.getFilesByCategory('photos');
        expect(photos.length, 3);
        expect(
          photos.map((f) => f.id).toSet(),
          containsAll([2001, 2002, 2003]),
        );

        // Videos collection
        final videos = await database.getFilesByCategory('videos');
        expect(videos.length, 1);
        expect(videos.first.id, 2004);

        // Documents collection
        final documents = await database.getFilesByCategory('documents');
        expect(documents.length, 1);
        expect(documents.first.id, 2005);

        // Collection counts
        final counts = await database.getCollectionCounts();
        expect(counts['documents'], 1);
        expect(counts['videos'], 1);
      },
    );
  });
}

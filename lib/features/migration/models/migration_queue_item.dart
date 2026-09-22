import 'dart:math';

/// Status of an item in the migration queue.
enum MigrationItemStatus { pending, uploading, uploaded, failed, skipped }

extension MigrationItemStatusExtension on MigrationItemStatus {
  String toDbString() => name;

  static MigrationItemStatus fromDbString(String value) {
    switch (value.toLowerCase()) {
      case 'uploading':
        return MigrationItemStatus.uploading;
      case 'uploaded':
        return MigrationItemStatus.uploaded;
      case 'failed':
        return MigrationItemStatus.failed;
      case 'skipped':
        return MigrationItemStatus.skipped;
      case 'pending':
      default:
        return MigrationItemStatus.pending;
    }
  }
}

/// Represents a single file staged for migration to Telegram Saved Messages.
///
/// Features:
/// - Stable [telegramRandomId] generated once and persisted across retries and crashes
/// - Exact [sha256] for cross-path content deduplication
/// - Explicit [status] lifecycle tracking with failure reason
class MigrationQueueItem {
  final int? id;
  final String localPath;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final String mimeType;
  final String category;
  final MigrationItemStatus status;
  final int retryCount;
  final int telegramRandomId;
  final int? telegramMessageId;
  final int? telegramFileId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MigrationQueueItem({
    this.id,
    required this.localPath,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.mimeType,
    required this.category,
    this.status = MigrationItemStatus.pending,
    this.retryCount = 0,
    required this.telegramRandomId,
    this.telegramMessageId,
    this.telegramFileId,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory creating a brand new pending migration item with a stable random ID.
  factory MigrationQueueItem.create({
    required String localPath,
    required String fileName,
    required int sizeBytes,
    required String sha256,
    required String mimeType,
    required String category,
    int? telegramRandomId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return MigrationQueueItem(
      localPath: localPath,
      fileName: fileName,
      sizeBytes: sizeBytes,
      sha256: sha256,
      mimeType: mimeType,
      category: category,
      status: MigrationItemStatus.pending,
      retryCount: 0,
      telegramRandomId: telegramRandomId ?? generateStableRandomId(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Generates a positive 63-bit integer for Telegram MTProto randomId.
  static int generateStableRandomId() {
    final rng = Random();
    final high = rng.nextInt(0x7FFFFFFF);
    final low = rng.nextInt(0x7FFFFFFF);
    final id = (high << 32) | low;
    return id == 0 ? 1 : id.abs();
  }

  MigrationQueueItem copyWith({
    int? id,
    String? localPath,
    String? fileName,
    int? sizeBytes,
    String? sha256,
    String? mimeType,
    String? category,
    MigrationItemStatus? status,
    int? retryCount,
    int? telegramRandomId,
    int? telegramMessageId,
    int? telegramFileId,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MigrationQueueItem(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha256: sha256 ?? this.sha256,
      mimeType: mimeType ?? this.mimeType,
      category: category ?? this.category,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      telegramRandomId: telegramRandomId ?? this.telegramRandomId,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      telegramFileId: telegramFileId ?? this.telegramFileId,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'localPath': localPath,
      'fileName': fileName,
      'sizeBytes': sizeBytes,
      'sha256': sha256,
      'mimeType': mimeType,
      'category': category,
      'status': status.toDbString(),
      'retryCount': retryCount,
      'telegramRandomId': telegramRandomId,
      'telegramMessageId': telegramMessageId,
      'telegramFileId': telegramFileId,
      'errorMessage': errorMessage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory MigrationQueueItem.fromMap(Map<String, dynamic> map) {
    return MigrationQueueItem(
      id: map['id'] as int?,
      localPath: map['localPath'] as String,
      fileName: map['fileName'] as String,
      sizeBytes: map['sizeBytes'] as int,
      sha256: map['sha256'] as String,
      mimeType: map['mimeType'] as String,
      category: map['category'] as String,
      status: MigrationItemStatusExtension.fromDbString(
        map['status'] as String,
      ),
      retryCount: (map['retryCount'] as int?) ?? 0,
      telegramRandomId: map['telegramRandomId'] as int,
      telegramMessageId: map['telegramMessageId'] as int?,
      telegramFileId: map['telegramFileId'] as int?,
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  @override
  String toString() =>
      'MigrationQueueItem(id: $id, file: $fileName, status: ${status.name}, retries: $retryCount, msgId: $telegramMessageId)';
}

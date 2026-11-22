import 'package:cloud_firestore/cloud_firestore.dart';

/// A single message on the public board.
///
/// Ownership is decided at write time: [authorUid] is stored when the message
/// is created and is never trusted from the client on update or delete. The
/// security rules compare it against the signed-in user's uid.
class Message {
  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;

  const Message({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    this.createdAt,
    this.editedAt,
  });

  /// True when [uid] is the author of this message.
  bool isOwnedBy(String? uid) => uid != null && authorUid == uid;

  /// True when the message has been edited at least once.
  bool get isEdited => editedAt != null;

  factory Message.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Message(
      id: snap.id,
      text: data['text'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Unknown',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }
}

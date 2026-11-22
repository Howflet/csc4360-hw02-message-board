import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message.dart';

/// Every Cloud Firestore read and write lives here.
///
/// The public `messages` collection is kept separate from each user's private
/// `users/{uid}` document — the same shape the security rules enforce.
class BoardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('messages');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Live stream of the board, ordered by the server-assigned `createdAt`.
  /// `snapshots()` re-emits on every change, so another device's post appears
  /// without a refresh.
  Stream<List<Message>> messagesStream() {
    return _messages
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Message.fromSnapshot).toList());
  }

  /// Mints a fresh document id without writing. Used as an idempotency key so
  /// a retry of the same post targets the same document.
  String newMessageId() => _messages.doc().id;

  /// Creates a message. When [id] is supplied it becomes the document id,
  /// which makes the write idempotent: posting twice with the same id leaves
  /// one document, not two (the duplicate-submit guard / Spice #4).
  Future<String> createMessage({
    required String text,
    required String authorUid,
    required String authorName,
    String? id,
  }) async {
    final docRef = id == null ? _messages.doc() : _messages.doc(id);
    await docRef.set({
      'text': text,
      'authorUid': authorUid,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
    });
    return docRef.id;
  }

  /// Updates only the text of one message and records when it was edited.
  Future<void> updateMessage({
    required String messageId,
    required String text,
  }) {
    return _messages.doc(messageId).update({
      'text': text,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a single message document.
  Future<void> deleteMessage(String messageId) {
    return _messages.doc(messageId).delete();
  }

  /// Writes the private user record created at registration. The document id
  /// is the auth uid, so this write is idempotent by construction.
  Future<void> saveUserRecord({
    required String uid,
    required String firstName,
    required String lastName,
    required String role,
  }) {
    return _users.doc(uid).set({
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }
}

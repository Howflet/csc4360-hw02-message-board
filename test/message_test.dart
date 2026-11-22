import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/models/message.dart';

void main() {
  group('Message ownership and edit state', () {
    const message = Message(
      id: 'abc',
      text: 'Hello board',
      authorUid: 'user-1',
      authorName: 'Ada',
    );

    test('isOwnedBy is true for the author and false otherwise', () {
      expect(message.isOwnedBy('user-1'), isTrue);
      expect(message.isOwnedBy('user-2'), isFalse);
      expect(message.isOwnedBy(null), isFalse);
    });

    test('isEdited is false without an editedAt timestamp', () {
      expect(message.isEdited, isFalse);
    });

    test('isEdited is true once editedAt is set', () {
      final edited = Message(
        id: 'abc',
        text: 'Hello board',
        authorUid: 'user-1',
        authorName: 'Ada',
        createdAt: DateTime(2026, 11, 21),
        editedAt: DateTime(2026, 11, 21, 14, 30),
      );
      expect(edited.isEdited, isTrue);
    });
  });
}

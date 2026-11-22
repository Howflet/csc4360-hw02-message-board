import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';
import '../utils/error_messages.dart';
import '../utils/formatters.dart';

/// The live message board. Renders from `snapshots()`, so new posts from any
/// device appear without a refresh. Update/delete are offered only on the
/// signed-in user's own messages — rules are the real guard behind them.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.user});

  final User user;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final AuthService _auth = AuthService();
  final BoardService _board = BoardService();

  final TextEditingController _composeController = TextEditingController();

  bool _isSubmitting = false;
  String? _submitError;

  /// Idempotency key for the current post. Reused on retry so a repeated
  /// submit targets the same document and cannot create a duplicate.
  String? _pendingMessageId;

  @override
  void dispose() {
    _composeController.dispose();
    super.dispose();
  }

  String get _authorName {
    final display = widget.user.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    return widget.user.email ?? 'Unknown';
  }

  Future<void> _postMessage() async {
    final text = _composeController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    // Generate the id once per post and keep it for retries.
    _pendingMessageId ??= _board.newMessageId();

    try {
      await _board.createMessage(
        text: text,
        authorUid: widget.user.uid,
        authorName: _authorName,
        id: _pendingMessageId,
      );
      if (!mounted) return;
      _composeController.clear();
      _pendingMessageId = null;
    } catch (e) {
      if (mounted) setState(() => _submitError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Update your message…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText == null || newText.isEmpty || newText == message.text) return;

    try {
      await _board.updateMessage(messageId: message.id, text: newText);
    } catch (e) {
      if (mounted) _showSnack(friendlyError(e));
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _board.deleteMessage(message.id);
    } catch (e) {
      if (mounted) _showSnack(friendlyError(e));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBoard()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return StreamBuilder<List<Message>>(
      stream: _board.messagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(onRetry: () => setState(() {}));
        }
        final messages = snapshot.data ?? const <Message>[];
        if (messages.isEmpty) {
          return const _EmptyState();
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) =>
              _MessageTile(
                message: messages[index],
                isOwn: messages[index].isOwnedBy(widget.user.uid),
                onEdit: () => _editMessage(messages[index]),
                onDelete: () => _deleteMessage(messages[index]),
              ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composeController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write a message…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Post',
                    onPressed:
                        _isSubmitting || _composeController.text.trim().isEmpty
                            ? null
                            : _postMessage,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.isOwn,
    required this.onEdit,
    required this.onDelete,
  });

  final Message message;
  final bool isOwn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatTimestamp(message.createdAt),
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                if (isOwn) ...[
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: colorScheme.error),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            Text(message.text),
            if (message.isEdited)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'edited',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No messages yet. Be the first to post!'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Could not load the board.'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

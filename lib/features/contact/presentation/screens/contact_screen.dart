import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ContactType {
  bug('bug', '🐛 Signalement de bug'),
  improvement('improvement', "💡 Demande d'amélioration"),
  other('other', '💬 Autre message');

  const ContactType(this.value, this.label);
  final String value;
  final String label;
}

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  ContactType _selectedType = ContactType.bug;
  final _messageController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _errorMessage = 'Veuillez écrire un message.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.functions.invoke(
        'send-contact-email',
        body: {
          'type': _selectedType.value,
          'message': message,
          if (user?.email != null) 'userEmail': user!.email,
        },
      );
      if (mounted) {
        setState(() {
          _sent = true;
          _isSending = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = "Erreur lors de l'envoi. Réessayez.";
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _sent = false;
      _selectedType = ContactType.bug;
      _messageController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF6EF),
        title: const Text('Contact'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _sent ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFFE8794A),
              size: 72,
            ),
            const SizedBox(height: 24),
            Text(
              'Message envoyé !',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D2D2D),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Merci pour votre retour. Nous le lirons avec attention.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF757575)),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Envoyer un autre message'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Une question, un bug, une idée ?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D2D2D),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nous lisons tous les messages et répondons sous 48h.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF757575)),
          ),
          const SizedBox(height: 32),

          // Type de message
          Text(
            'Type de message',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF2D2D2D),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ContactType>(
            segments: ContactType.values
                .map(
                  (type) => ButtonSegment<ContactType>(
                    value: type,
                    label: Text(
                      type.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            selected: {_selectedType},
            onSelectionChanged: (set) =>
                setState(() => _selectedType = set.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: const Color(0xFFE8794A),
              selectedForegroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // Message
          Text(
            'Votre message',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF2D2D2D),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 6,
            minLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Décrivez votre problème ou votre idée…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5CC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5CC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE8794A), width: 2),
              ),
              errorText: _errorMessage,
            ),
          ),

          const SizedBox(height: 32),

          // Bouton envoyer
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8794A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Envoyer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

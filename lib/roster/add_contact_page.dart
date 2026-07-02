import 'package:flutter/material.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/roster/roster_repo.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

class AddContactPage extends StatefulWidget {
  final UiAccount account;
  const AddContactPage({Key? key, required this.account}) : super(key: key);

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _jidController = TextEditingController();
  final _rosterRepo = sl.get<RosterRepo>();
  String? _errorMessage;
  bool _sent = false;

  @override
  void dispose() {
    _jidController.dispose();
    super.dispose();
  }

  void _sendRequest() {
    final jid = _jidController.text.trim();

    if (jid.isEmpty || !jid.contains('@')) {
      setState(() => _errorMessage = 'Digite um JID válido (usuario@servidor.com)');
      return;
    }

    _rosterRepo.addContact(widget.account, jid);

    setState(() {
      _errorMessage = null;
      _sent = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Adicionar contato',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digite o JID completo da pessoa que você quer adicionar. '
              'Ela vai receber um pedido para confirmar.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _jidController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'usuario@servidor.com',
                prefixIcon: const Icon(Icons.person_add_alt_outlined),
                contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onSubmitted: (_) => _sendRequest(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            if (_sent) ...[
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Pedido enviado!', style: TextStyle(color: Colors.green)),
                ],
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sent ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Enviar pedido',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

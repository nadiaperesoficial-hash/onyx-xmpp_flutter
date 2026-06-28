import 'package:whixp/whixp.dart';

class AccountRepo {
  Whixp? _whixp;

  bool get isConnected => _whixp?.state == TransportState.connected;

  Stream<TransportState> get connectionStateStream =>
      _whixp?.stateStream ?? Stream.empty();

  // Método de login com fallback de portas e tratamento de erro
  Future<void> login({
    required String username,
    required String password,
    required String domain,
    int port = 5222,
  }) async {
    // Lista de portas a tentar (prioridade: 443, 5222)
    final ports = [443, 5222];
    List<String> errors = [];

    for (final p in ports) {
      try {
        // Cria uma nova instância para cada tentativa
        _whixp = Whixp(
          jabberID: '$username@$domain/mobile',
          password: password,
          host: domain,
          port: p,
          useTLS: true,
          reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
          logger: Log(enableWarning: true, enableError: true),
        );

        // Adiciona listener de estado
        _whixp!.addEventHandler<TransportState>('state', (state) {
          if (state == TransportState.connected) {
            print('✅ Conectado via porta $p');
          } else if (state == TransportState.disconnected) {
            print('❌ Desconectado da porta $p');
          }
        });

        // Tenta conectar com timeout de 15 segundos
        await _whixp!.connect().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Timeout ao conectar na porta $p'),
        );

        // Se chegou aqui, conectou com sucesso
        await _whixp!.sendPresence(Presence(type: PresenceType.available));
        print('✅ Login bem-sucedido na porta $p');
        return; // Sai do loop, sucesso!
      } catch (e) {
        // Guarda o erro e tenta a próxima porta
        String errorMsg = 'Porta $p: ${e.toString().replaceAll('Exception: ', '')}';
        errors.add(errorMsg);
        print(errorMsg);
        // Desconecta se ainda estiver conectado
        try { await _whixp?.disconnect(); } catch (_) {}
        _whixp = null;
        continue;
      }
    }

    // Se nenhuma porta funcionou, lança um erro com todos os detalhes
    throw Exception('Falha em todas as portas:\n${errors.join('\n')}');
  }

  // Método de registro (usando a porta fornecida, sem fallback)
  Future<void> register({
    required String username,
    required String password,
    required String domain,
    int port = 5222,
  }) async {
    try {
      final tempJid = '$username@$domain/register';
      _whixp = Whixp(
        jabberID: tempJid,
        password: password,
        host: domain,
        port: port,
        useTLS: true,
        logger: Log(enableWarning: true, enableError: true),
      );

      await _whixp!.connect().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Timeout ao registrar na porta $port'),
      );

      final iq = Iq(
        type: IqType.set,
        to: JID.fromString(domain),
        children: [
          XmlElement(
            name: 'query',
            attributes: {'xmlns': 'jabber:iq:register'},
            children: [
              XmlElement(name: 'username', text: username),
              XmlElement(name: 'password', text: password),
            ],
          ),
        ],
      );

      await _whixp!.sendIq(iq);
      await _whixp!.disconnect();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_whixp != null && isConnected) {
      await _whixp!.sendPresence(Presence(type: PresenceType.unavailable));
      await _whixp!.disconnect();
    }
  }

  Future<void> sendMessage(String to, String body) async {
    if (!isConnected) throw Exception('Não conectado');
    final message = Message(
      to: JID.fromString(to),
      body: body,
      type: MessageType.chat,
    );
    await _whixp!.sendMessage(message);
  }
}

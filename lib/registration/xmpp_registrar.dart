import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class XmppRegistrar {
  final String domain;
  final String host;
  final int port;
  final String username;
  final String password;

  static const _wsUrl = 'wss://laylaprs-meuchatxmpp.hf.space/xmpp-websocket';
  static const _wsDomain = 'onyx.im';

  XmppRegistrar({
    required this.domain,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  Future<void> register() async {
    final channel = WebSocketChannel.connect(
      Uri.parse(_wsUrl),
      protocols: ['xmpp'],
    );

    final completer = Completer<void>();
    final buffer = StringBuffer();
    String stage = 'open';

    channel.stream.listen(
      (data) {
        buffer.write(data.toString());
        final xml = buffer.toString();

        if (stage == 'open' && xml.contains('<open')) {
          stage = 'get_fields';
          buffer.clear();
          channel.sink.add(
            '<iq type="get" id="reg1" to="$_wsDomain">'
            '<query xmlns="jabber:iq:register"/>'
            '</iq>',
          );
        } else if (stage == 'get_fields' && xml.contains('jabber:iq:register')) {
          stage = 'registering';
          buffer.clear();
          channel.sink.add(
            '<iq type="set" id="reg2" to="$_wsDomain">'
            '<query xmlns="jabber:iq:register">'
            '<username>$username</username>'
            '<password>$password</password>'
            '</query>'
            '</iq>',
          );
        } else if (stage == 'registering') {
          if (xml.contains('type="result"')) {
            if (!completer.isCompleted) completer.complete();
          } else if (xml.contains('type="error"')) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(_parseError(xml)));
            }
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Conexão encerrada inesperadamente'));
        }
      },
    );

    // Abre stream WebSocket XMPP
    channel.sink.add(
      "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
      "to='$_wsDomain' version='1.0'/>",
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout ao registrar conta'),
      );
    } finally {
      channel.sink.add("<close xmlns='urn:ietf:params:xml:ns:xmpp-websocket'/>");
      await channel.sink.close();
    }
  }

  String _parseError(String xml) {
    if (xml.contains('conflict')) return 'Usuário já existe';
    if (xml.contains('not-acceptable')) return 'Dados inválidos';
    if (xml.contains('forbidden')) return 'Registro não permitido';
    if (xml.contains('not-allowed')) return 'Registro desabilitado';
    return 'Erro ao criar conta';
  }
}

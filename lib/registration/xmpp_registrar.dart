import 'dart:async';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/account/xmpp_servers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class XmppRegistrar {
  final String domain;
  final String username;
  final String password;

  XmppRegistrar({
    required this.domain,
    required String host,
    required int port,
    required this.username,
    required this.password,
  });

  /// Tenta registrar a conta testando as URLs candidatas em ordem
  /// (porta 443 primeiro, 5280 como fallback). Lança exceção se nenhuma
  /// porta funcionar ou se o servidor recusar o registro.
  Future<void> register() async {
    final effectiveDomain = domain.isNotEmpty ? domain : UiAccount.serverDomain;
    final urls = candidateWsUrls(effectiveDomain);

    Object? lastError;
    for (final url in urls) {
      try {
        await _registerOnUrl(url, effectiveDomain);
        return; // sucesso, não tenta mais nada
      } catch (e) {
        lastError = e;
        // Se o erro for de regra de negócio do servidor (ex: usuário já
        // existe), não adianta tentar outra porta do mesmo domínio: ainda
        // assim seguimos tentando, pois pode ser problema só dessa porta.
        continue;
      }
    }

    throw Exception(lastError?.toString() ?? 'Falha ao registrar em todas as portas testadas');
  }

  Future<void> _registerOnUrl(String url, String toDomain) async {
    final channel = WebSocketChannel.connect(Uri.parse(url), protocols: ['xmpp']);

    final completer = Completer<void>();
    final buffer = StringBuffer();
    String stage = 'open';

    // Namespace correto conforme RFC 7395. O bug anterior usava
    // 'urn:ietf:params:xml:ns:xmpp-websocket', que o servidor rejeita
    // com <invalid-namespace/>.
    const nsFraming = 'urn:ietf:params:xml:ns:xmpp-framing';

    late StreamSubscription sub;
    sub = channel.stream.listen(
      (data) {
        buffer.write(data.toString());
        final xml = buffer.toString();

        if (xml.contains('stream:error') || xml.contains('invalid-namespace')) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('[stream error] $xml'));
          }
          return;
        }

        if (stage == 'open' && xml.contains('<open')) {
          stage = 'get_fields';
          buffer.clear();
          channel.sink.add(
            '<iq type="get" id="reg1" to="$toDomain">'
            '<query xmlns="jabber:iq:register"/>'
            '</iq>',
          );
        } else if (stage == 'get_fields' && xml.contains('jabber:iq:register')) {
          stage = 'registering';
          buffer.clear();
          channel.sink.add(
            '<iq type="set" id="reg2" to="$toDomain">'
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

    channel.sink.add(
      "<open xmlns='$nsFraming' to='$toDomain' version='1.0'/>",
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Timeout ao registrar conta em $url'),
      );
    } finally {
      await sub.cancel();
      try {
        channel.sink.add("<close xmlns='$nsFraming'/>");
        await channel.sink.close();
      } catch (_) {}
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

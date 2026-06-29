import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account);
  void unregister(XmppAccount account);
}

class XmppAccount {
  final String username;
  final String fullJid;
  final String domain;
  final String password;
  final int port;

  XmppAccount(this.username, this.fullJid, this.domain, this.password, this.port);
}

class UiAccount {
  final XmppAccount account;
  WebSocketChannel? _channel;
  final _stateSubject = BehaviorSubject<AccountState>();

  static const wsUrl = 'wss://prosody-server-production.up.railway.app/xmpp-websocket';
  static const serverDomain = 'onyx.im';

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  WebSocketChannel? get channel => _channel;
  String get id => '${account.username}@${account.domain}';

  set accountState(AccountState state) => _stateSubject.add(state);

  void sendXml(String xml) => _channel?.sink.add(xml);

  @override
  bool operator ==(Object other) =>
      other is UiAccount &&
      account.username == other.account.username &&
      account.domain == other.account.domain;

  @override
  int get hashCode => Object.hash(account.username, account.domain);

  UiAccount(this.account);
}

class AccountRepoImpl implements AccountRepo {
  final _accountSubject = BehaviorSubject<List<UiAccount>>();
  final List<UiAccount> _accountsList = [];

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    uiAccount.accountState = AccountRegistering(account: account);
    _connect(uiAccount);

    return uiAccount;
  }

  void _connect(UiAccount uiAccount) {
    final account = uiAccount.account;
    final buffer = StringBuffer();
    String stage = 'open';

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(UiAccount.wsUrl),
        protocols: ['xmpp'],
      );
      uiAccount._channel = channel;

      channel.stream.listen(
        (data) {
          buffer.write(data.toString());
          final xml = buffer.toString();

          if (stage == 'open' && xml.contains('<open')) {
            stage = 'features';
            buffer.clear();
          } else if (stage == 'features' && xml.contains('stream:features')) {
            stage = 'auth';
            buffer.clear();
            // SASL PLAIN
            final creds = base64.encode(
              utf8.encode('\x00${account.username}\x00${account.password}'),
            );
            channel.sink.add(
              "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' "
              "mechanism='PLAIN'>$creds</auth>",
            );
          } else if (stage == 'auth') {
            if (xml.contains('<success')) {
              stage = 'reopen';
              buffer.clear();
              // Reabre stream após autenticação
              channel.sink.add(
                "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
                "to='${UiAccount.serverDomain}' version='1.0'/>",
              );
            } else if (xml.contains('<failure')) {
              uiAccount.accountState = AccountUnregistered(
                account: account,
                message: '[auth] Usuário ou senha incorretos',
              );
            }
          } else if (stage == 'reopen' && xml.contains('<open')) {
            stage = 'bind';
            buffer.clear();
            // Bind resource
            channel.sink.add(
              "<iq type='set' id='bind1'>"
              "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
              "<resource>simple_chat</resource>"
              "</bind>"
              "</iq>",
            );
          } else if (stage == 'bind' && xml.contains('urn:ietf:params:xml:ns:xmpp-bind')) {
            stage = 'session';
            buffer.clear();
            // Session
            channel.sink.add(
              "<iq type='set' id='sess1'>"
              "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>"
              "</iq>",
            );
          } else if (stage == 'session' && xml.contains('id=\'sess1\'') ||
              (stage == 'session' && xml.contains('id="sess1"'))) {
            stage = 'connected';
            buffer.clear();
            // Presence
            channel.sink.add("<presence/>");
            uiAccount.accountState = AccountRegistered(account: account);
          }
        },
        onError: (e) {
          uiAccount.accountState = AccountUnregistered(
            account: account,
            message: '[ws error] ${e.toString()}',
          );
        },
        onDone: () {
          if (stage != 'connected') {
            uiAccount.accountState = AccountUnregistered(
              account: account,
              message: '[ws done] Conexão encerrada na fase: $stage',
            );
          }
        },
      );

      // Abre stream WebSocket XMPP
      channel.sink.add(
        "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
        "to='${UiAccount.serverDomain}' version='1.0'/>",
      );
    } catch (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[connect error] ${e.toString()}',
      );
    }
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${UiAccount.serverDomain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx]._channel?.sink.close();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account);
  void unregister(XmppAccount account);
  Future<bool> criarNovaContaNoServidor(XmppAccount account); // Contrato do método de registro
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
  Whixp? _client;
  final _stateSubject = BehaviorSubject<AccountState>();

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  Whixp? get client => _client;
  String get id => '${account.username}@${account.domain}';

  set accountState(AccountState state) => _stateSubject.add(state);

  @override
  bool operator ==(other) =>
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

  // 1. MÉTODO PARA REALIZAR LOGIN (CONECTAR CONTA EXISTENTE)
  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: account.domain, 
      port: account.port,   
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: RandomBackoffReconnectionPolicy(3, 15),
      useTLS: false, // Define como false para permitir a negociação STARTTLS padrão do chalec.org na porta 5222
      onBadCertificateCallback: (certificate) => true,
    );

    uiAccount._client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    client.addEventHandler<TransportState>('state', (state) {
      if (state == null) return;
      print("STATUS CONEXÃO: $state");

      if (state == TransportState.connected) {
        uiAccount.accountState = AccountRegistered(account: account);
      } else if (state == TransportState.disconnected) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: 'A conexão foi encerrada.',
        );
      }
    });

    try {
      client.connect();
    } catch (e) {
      print("Erro ao tentar disparar o método connect: $e");
    }
    
    return uiAccount;
  }

  // 2. NOVO MÉTODO PARA CRIAR CONTA DO ZERO DIRETAMENTE PELO APLICATIVO
  @override
  Future<bool> criarNovaContaNoServidor(XmppAccount account) async {
    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: account.domain,
      port: account.port,
      internalDatabasePath: 'whixp_reg_${account.username}',
      useTLS: false,
      onBadCertificateCallback: (certificate) => true,
    );

    try {
      // Solicita o plugin nativo de registro em lote do protocolo XMPP
      final registration = client.getPlugin<InBandRegistration>('registration');
      
      if (registration != null) {
        // Envia os dados para a criação de conta limpa
        await registration.register(
          username: account.username,
          password: account.password,
        );
        print("Conta criada com sucesso direto pelo app!");
        return true;
      }
      return false;
    } catch (e) {
      print("Erro ao criar conta no servidor: $e");
      return false;
    }
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${account.domain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx]._client?.disconnect();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}

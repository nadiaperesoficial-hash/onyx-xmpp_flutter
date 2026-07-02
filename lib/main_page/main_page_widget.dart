import 'package:flutter/material.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/service_locator/service_locator.dart';
import 'main_page_bloc.dart';
import 'main_page_content.dart';
import 'profile_page.dart';

class MainPage extends StatefulWidget {
  static const String TAG = 'main';
  final AccountBloc accountBloc;
  const MainPage(this.accountBloc, {Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final MainPageBloc _mainPageBloc = MainPageBloc();
  final _accountRepo = sl.get<AccountRepo>();

  static const _accent = Color(0xFF1976D2);

  UiAccount? get _currentUiAccount {
    final state = widget.accountBloc.state;
    if (state is AccountRegistered && state.account != null) {
      final targetId = '${state.account!.username}@${state.account!.domain}';
      for (final a in _accountRepo.accounts.valueOrNull ?? <UiAccount>[]) {
        if (a.id == targetId) return a;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatListPage(mainPageBloc: _mainPageBloc),
      RosterPage(mainPageBloc: _mainPageBloc),
      _CallsPlaceholder(),
      ProfilePage(accountBloc: widget.accountBloc),
    ];

    final titles = ['Chat', 'Contacts', 'Calls', 'Perfil'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ]
            : null,
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: _accent,
              onPressed: () {
                final account = _currentUiAccount;
                if (account == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddContactPageWrapper(account: account),
                  ),
                );
              },
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _accent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            activeIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _CallsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Em breve', style: TextStyle(color: Colors.grey)),
    );
  }
}

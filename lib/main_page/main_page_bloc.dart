import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/main_page/main_page_event.dart';
import 'package:simple_chat/main_page/main_page_state.dart';
import 'package:simple_chat/repo/chats_repo.dart';
import 'package:simple_chat/repo/ui_chat.dart';
import 'package:simple_chat/roster/roster_repo.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

enum MainPageTab { CHAT_LIST, ROSTER }

class MainPageBloc extends Bloc<MainPageEvent, MainPageState> {
  MainPageTab _activeTab = MainPageTab.ROSTER;
  final _rosterRepo = sl.get<RosterRepo>();
  final _chatListRepo = sl.get<ChatsRepo>();
  List<UiBuddy> _activeRoster = [];
  List<UiChat> _activeChats = [];

  MainPageBloc() : super(MainPageRosterList(activeList: [])) {
    on<MainPageChatListTabActive>((event, emit) {
      _activeTab = MainPageTab.CHAT_LIST;
      emit(MainPageChatList(activeList: _activeChats));
    });
    on<MainPageRosterTabActive>((event, emit) {
      _activeTab = MainPageTab.ROSTER;
      emit(MainPageRosterList(activeList: _activeRoster));
    });
    _initStreams();
  }

  void _initStreams() {
    _rosterRepo.rosterStream
        .debounceTime(const Duration(milliseconds: 1000))
        .listen((roster) {
      _activeRoster = roster;
      if (_activeTab == MainPageTab.ROSTER) {
        add(MainPageRosterTabActive());
      }
    });

    _chatListRepo.chatsStream
        .debounceTime(const Duration(milliseconds: 1000))
        .listen((chats) {
      _activeChats = chats;
      if (_activeTab == MainPageTab.CHAT_LIST) {
        add(MainPageChatListTabActive());
      }
    });
  }
}

class DbChat {
  int? uuid;
  String name;
  String account_id;
  String jid;
  int since;
  int type;
  int status;

  static const TABLE = 'CHATS';
  static const COLUMN_UUID = 'UUID';
  static const COLUMN_NAME = 'NAME';
  static const COLUMN_ACCOUNT_ID = 'ACCOUNT_ID';
  static const COLUMN_JID = 'JID';
  static const COLUMN_SINCE = 'SINCE';
  static const COLUMN_TYPE = 'TYPE';
  static const COLUMN_STATUS = 'STATUS';

  DbChat({
    this.uuid,
    required this.name,
    required this.account_id,
    required this.jid,
    required this.since,
    required this.type,
    required this.status,
  });

  DbChat.fromMap(Map map)
      : uuid = map[COLUMN_UUID] as int?,
        name = map[COLUMN_NAME] as String,
        account_id = map[COLUMN_ACCOUNT_ID] as String,
        jid = map[COLUMN_JID] as String,
        since = map[COLUMN_SINCE] as int,
        type = map[COLUMN_TYPE] as int,
        status = map[COLUMN_STATUS] as int;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      COLUMN_NAME: name,
      COLUMN_ACCOUNT_ID: account_id,
      COLUMN_JID: jid,
      COLUMN_SINCE: since,
      COLUMN_TYPE: type,
      COLUMN_STATUS: status,
    };
    if (uuid != null) map[COLUMN_UUID] = uuid;
    return map;
  }

  static String getTableCreateString() => '''
    CREATE TABLE $TABLE (
      $COLUMN_UUID INTEGER PRIMARY KEY,
      $COLUMN_NAME TEXT NOT NULL,
      $COLUMN_ACCOUNT_ID TEXT NOT NULL,
      $COLUMN_JID TEXT NOT NULL,
      $COLUMN_SINCE INTEGER NOT NULL,
      $COLUMN_TYPE INTEGER NOT NULL,
      $COLUMN_STATUS INTEGER NOT NULL
    )
  ''';
}

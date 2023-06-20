part of websocketchat;

class Room {
  final String _id;
  final Map<String, Client> _clients;
  final List<Message> _messages;

  void Function(String id)? _onRoomDisposed;
  void Function(Client)? _onClientRemoved;
  StreamSubscription? _streamSub;

  String get id => _id;

  int get totalClients => _clients.length;

  List<Client> get clients => _clients.values.toList();

  List<Message> get messages => _messages;

  set onClientRemoved(void Function(Client) callback) {
    _onClientRemoved = callback;
  }

  set onRoomDisposed(void Function(String id) onRoomDisposed) {
    _onRoomDisposed = onRoomDisposed;
  }

  Room._(
    this._id,
    this._clients,
    this._messages,
    this._onClientRemoved,
  );

  Future<Db> database() async {
    final db = await Db.create(
        'mongodb+srv://doadmin:wu3C5Y70p49Rey21@eml-database-6c1feb38.mongo.ondigitalocean.com/admin?tls=true&authSource=admin&replicaSet=eml-database');
    await db.open();
    return db;
  }

  /// Creates a [Room] with a id and list of clients
  factory Room.create(String id,
      [List? clients, void Function(Client)? onClientRemoved]) {
    return Room._(
      id,
      Map<String, Client>.fromIterable(
        clients ?? [],
        key: (client) => client.id,
        value: (client) => client,
      ),
      <Message>[],
      onClientRemoved,
    );
  }

  /// Creates a [Room] with uinque id and empty clientList
  factory Room.empty() {
    return Room.create(Uuid().v1(), <Client>[]);
  }

  Future<void> addClient(Client client) async {
    Db databases = await database();
    final col = databases.collection('room');

    // check if client already exist
    if (_clients.containsKey(client.id)) {
      for (int i = 0; i < _clients.length; i++) {
        print(_clients[i]!.name);
      }
      return;
    }
    // add client to room
    _clients[client.id] = client;

    // sends previous messages to client
    if (_messages.isNotEmpty) {
      // _messages.forEach((m) => client.sendMessage(m));
      _messages.forEach((m) {
        print(m);
      });
    }

    // redirects client messages to users
    client.setUpStream(
      onEvent: (message) async {
        sendBrodCastMessage(message);
        _messages.add(message);
        Map<String, dynamic> jsonMsg = message.toMap();
        await col.insert(jsonMsg);
      },
      onClosed: (client) {
        removeClient(client.id);
      },
    );
    // disables self-destruction on rejoin
    if (_clients.isNotEmpty && _streamSub != null) {
      await _streamSub?.cancel();
      print('self-destruction disabled');
    }
  }

  // checks if client already exists
  bool isClientExist(String id) => _clients.containsKey(id);

  // finds and returns client
  Client? findClient(String id) =>
      _clients.containsKey(id) ? _clients[id] : null;

  // removes client from the
  void removeClient(String id) {
    if (isClientExist(id)) {
      final removedClient = _clients.remove(id);
      _onClientRemoved?.call(removedClient!);

      // set room self-destruction when users are empty
      if (_clients.isEmpty) {
        // print('Self destruction started');
        _streamSub?.cancel(); // cancels previous sub
        _streamSub = Stream.fromFuture(
          Future.delayed(Duration(minutes: 5)),
        ) //returns after 10 seconds
            .listen((_) {});
        _streamSub?.onDone(() async {
          dispose();
          // print('room "$_id" disposed ');
          _onRoomDisposed?.call(_id);
        });
      }
    }
  }

  // sends messages to all clients in the room
  void sendBrodCastMessage(Message message) {
    _clients.values.forEach((client) => client.sendMessage(message));
  }

  void dispose() async {
    await _streamSub?.cancel();
    _messages.clear();
  }

  @override
  String toString() {
    return '''
Room(
  id: $_id,
  totalClients: $totalClients
)    
    ''';
  }
}

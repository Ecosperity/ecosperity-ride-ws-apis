import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'websocket_chat/websocket_chat.dart';

void main(List<String> arguments) async {
  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final chatWebSocket = WebSocketChat.create();

  Handler _wsHandler = webSocketHandler((webSocket) {
    webSocket.stream.listen((message) {
      print(message);
      webSocket.sink.add("echo $message");
    });
  });

  final _router = Router()..get('/api/v1/users/ws', _wsHandler);
  final wsHandler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(chatWebSocket.middleware)
      .addHandler(_router);
  final wsServer = await serve(wsHandler, ip, port)
      .whenComplete(() async => await chatWebSocket.dispose());
  print('Server listening on port ${wsServer.port}');
}

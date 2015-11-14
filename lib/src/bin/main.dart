library bwu_dev_server.bin.main;

import 'dart:io' as io;
import 'dart:async' show Future;
import 'package:bwu_dev_server/src/devserver.dart';
import 'package:unscripted/unscripted.dart';

Future main([List<String> arguments]) =>
    new Script(devServerArgs).execute(arguments);

const int defaultPort = 8080;
const int maxPort = 65535;

@Command(
    help: 'HTTP server for Dart client side development.',
    plugins: const [const Completion()])
@ArgExample('--port 8080', help: 'specify port')
Future devServerArgs(
    {@Option(
        help: 'The IP port to listen on.',
        abbr: 'p',
        parser: validatePort,
        defaultsTo: defaultPort)
    int port: defaultPort,
    @Option(
        help: 'The directory to serve.', abbr: 'd', parser: validateDirectory)
    io.Directory directory,
    @Option(
        help: 'The hostname or IP address to listen on.',
        defaultsTo: 'localhost')
    String host,
    @Option(help: 'The value for the "Access-Control-Allow-Origin" header.')
    String allowOrigin}) async {
  if (directory == null) {
    print('Serving default directory: ${io.Directory.current.path}.');
    directory = io.Directory.current;
  }
  final corsHeaders = <String, String>{};
  if (allowOrigin != null) {
    corsHeaders['Access-Control-Allow-Origin'] = allowOrigin;
  }
  io.InternetAddress address;
  try {
    address = new io.InternetAddress(host);
  } catch (_) {
    address = (await io.InternetAddress.lookup(host)).first;
  }
  new DevServer(port, directory, address, corsHeaders).start();
}

int validatePort(String port) {
  if (port == null) {
    throw 'Port "${port}" is invalid.';
  }
  print(port.runtimeType);
  try {
    int portValue = int.parse(port);
    if (portValue <= 0 || portValue >= maxPort) {
      throw 'Port "${portValue}" is outside of the valid range (0 <= port < ${maxPort}).';
    }
    return portValue;
  } on String catch (_) {
    rethrow;
  } catch (_) {
    throw 'Port "${port}" can\'t be parsed.';
  }
}

io.Directory validateDirectory(String path) {
  final dir = new io.Directory(path);
  if (!dir.existsSync()) {
    // TODO(zoechi) throw again when seaneagan/unscripted#112 is fixed
    // throw 'Directory "${dir.path}" not found.';
    print('Directory "${dir.path}" not found.');
    return null;
  } else {
    return new io.Directory(path);
  }
}

library bwu_dev_server.src.devserver;

import 'dart:io' as io;
import 'dart:async' show Future;
import 'package:shelf/shelf.dart' as s;
import 'package:shelf_cors/shelf_cors.dart' as s_cors;
import 'package:shelf/shelf_io.dart' as s_io;
import 'package:shelf_static/shelf_static.dart' as s_static;
//import 'package:shelf_route/shelf_route.dart' as s_route;
import 'package:collection/collection.dart' show UnmodifiableMapView;
import 'file_cache.dart';
import 'package_map.dart';

const String DEFAULT_HOST = 'localhost';

class DevServer {
  final int port;
  final io.Directory directory;
  final io.InternetAddress _address;
  final Map<String, String> _corsHeaders;
  final FileCache fileCache = new FileCache();

  Map<String, String> get corsHeaders => new UnmodifiableMapView(_corsHeaders);

  io.HttpServer _server;
  String get host => _server.address.host;

  String get urlBase => 'http://${_address}:${port}/';

  DevServer(this.port, this.directory, this._address, this._corsHeaders);

  Future destroy() => _server.close();

  Future start() async {
    assert(port != null);
    assert(directory != null);

    s.Pipeline pipeline = const s.Pipeline().addMiddleware(s.logRequests());

    if (corsHeaders != null && corsHeaders.isNotEmpty) {
      pipeline = pipeline.addMiddleware(
          s_cors.createCorsHeadersMiddleware(corsHeaders: corsHeaders));
    }

    pipeline = pipeline
        .addMiddleware(createCacheMiddleware(new FileCache()))
        .addMiddleware(createPackagesMiddleware(new PackageMaps(directory)));

//    Cascade cascade = new Cascade();
//    _directories.forEach((io.Directory dir) {
//      cascade = cascade.add(sstatic.createStaticHandler(dir.path,
//          defaultDocument: 'index.html', serveFilesOutsidePath: true));
//    });
    final staticHandler = s_static.createStaticHandler(directory.path,
        defaultDocument: 'index.html', serveFilesOutsidePath: true);

//    s_route.printRoutes(router);
    final handler = pipeline.addHandler(staticHandler);
    _server = await s_io.serve(handler, _address, port);
  }
}

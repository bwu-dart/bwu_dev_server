library bwu_dev_server.src.main;

import 'dart:io' as io;
import 'dart:async' show Future, Stream, StreamController;
import 'package:shelf/shelf.dart' as s;
import 'package:shelf_cors/shelf_cors.dart' as s_cors;
import 'package:shelf/shelf_io.dart' as s_io;
import 'package:shelf_static/shelf_static.dart' as s_static;
//import 'package:shelf_route/shelf_route.dart' as s_route;
import 'package:collection/collection.dart' show UnmodifiableMapView;

const String DEFAULT_HOST = 'localhost';

class DevServer {
  final int port;
  final io.Directory directory;
  final io.InternetAddress _address;
  final Map<String, String> _corsHeaders;
  final Map<String, CacheItem> _fileCache = <String, CacheItem>{};

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

    pipeline = pipeline.addMiddleware(cacheHandler);

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

  s.Handler cacheHandler(s.Handler innerHandler) {
    return (s.Request request) {
      final cachedItem = _fileCache[request.url.path];
      if (cachedItem != null) {
        print('${cachedItem.path} from cache.');
        // serve from cache
        cachedItem.touch();
        if (cachedItem.statusCode == 200) {
          return new s.Response.ok(cachedItem.contentStream,
              headers: cachedItem.headers);
        }
        return new s.Response(cachedItem.statusCode,
            headers: cachedItem.headers);
      }
      // forward to shelf_static
      final s.Response response = innerHandler(request);
      if (response.statusCode == 200 &&
          int.parse(response.headers['content-length']) > 1000000) {
        return response;
      }

      // create cache item
      StreamController<List<int>> streamController =
          new StreamController<List<int>>();
      Stream<List<int>> stream = streamController.stream.asBroadcastStream();

      final cacheItem = new CacheItem(request.url.path, response.statusCode,
          response.headers, int.parse(response.headers['content-length']));

      stream.listen((Iterable<int> data) {
        cacheItem.content.addAll(data);
      }).onDone(() {
        _fileCache[request.url.path] = cacheItem;
        assert(cacheItem.size == cacheItem.content.length);
      });

      var newResponse = new s.Response.ok(stream, headers: response.headers);
      response.read().pipe(streamController);

      // respond
      return newResponse;
    };
  }
}

class CacheItem {
  final String path;
  final int size;
  final int statusCode;
  DateTime _timeStamp;
  DateTime get timeStamp => _timeStamp;
  final List<int> content = <int>[];
  final Map<String, String> headers;
  CacheItem(this.path, this.statusCode, this.headers, this.size) {
    touch();
  }

  touch() => _timeStamp = new DateTime.now();
  Stream<List<int>> get contentStream =>
      new Stream<List<int>>.fromIterable([content]);
}

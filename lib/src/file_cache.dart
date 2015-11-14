library bwu_dev_server.src.file_cache;

import 'dart:async' show Stream, Timer, StreamController;
import 'package:shelf/shelf.dart' as s;

s.Middleware createCacheMiddleware(FileCache fileCache) =>
  (s.Handler innerHandler) {
    return (s.Request request) {
      final cachedItem = fileCache[request.url.path];
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
      if (response.statusCode == 200) {
        if(int.parse(response.headers['content-length']) > 1000000) {
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
          fileCache[request.url.path] = cacheItem;
          assert(cacheItem.size == cacheItem.content.length);
        });

        var newResponse = new s.Response.ok(stream, headers: response.headers);
        response.read().pipe(streamController);

        // respond
        return newResponse;
      } else {
        final cacheItem = new CacheItem(request.url.path, response.statusCode,
            response.headers, 0);
        fileCache[request.url.path] = cacheItem;
        print('Not found: ${request.url.path}');
        return response;
      }
    };
  } as s.Middleware;


class FileCache {
  final Map<String, CacheItem> _fileCache = <String, CacheItem>{};
  int maxCacheSize = 1024 * 1024 * 50;
  int _currentCacheSize = 0;
  Duration maxAge = const Duration(minutes: 15);
  Timer _timer;

  FileCache() {
    _timer = new Timer.periodic(
        const Duration(seconds: 20), (timer) => _evictExpired());
  }

  void operator []=(String key, CacheItem item) {
    _fileCache[item.path] = item;
    _currentCacheSize += item.size;
  }

  CacheItem operator [](String key) => _fileCache[key];

  CacheItem remove(String key) {
    final item = _fileCache[key];
    if(item != null) {
      _currentCacheSize -= item.size;
    }
    return _fileCache.remove(key);
  }

  void _evictExpired() {
    final keysByTime = _keysSortedDescendingBy(_Property.time);
    int pos = 0;
    while(_currentCacheSize > maxCacheSize && pos < keysByTime.length) {
      remove(keysByTime[pos++]);
    }

    final now = new DateTime.now();
    while(pos < keysByTime.length) {
      final key = keysByTime[pos++];
      final item = _fileCache[key];
      if(item.timeStamp.add(maxAge).compareTo(now) > 0) {
        remove(key);
      } else {
        break;
      }
    }
  }

  List<String> _keysSortedDescendingBy(_Property property) {
    return _fileCache.keys.toList()..sort((String key1, String key2) {
      var val1;
      var val2;
      switch(property) {
        case _Property.size:
          val1 = _fileCache[key1].size;
          val2 = _fileCache[key2].size;
          break;
        case _Property.time:
          val1 = _fileCache[key1].timeStamp;
          val2 = _fileCache[key2].timeStamp;
          break;
      }
      return Comparable.compare(val2, val1);
    } as Comparator<String>);
  }
}

enum _Property { size, time}

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

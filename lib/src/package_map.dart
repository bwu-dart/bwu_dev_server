library bwu_dev_server.src.package_map;

import 'dart:io' as io;
import 'dart:async' show Stream;
import 'package:path/path.dart' as path;
import 'package:package_config/discovery.dart';
import 'package:shelf/shelf.dart' as s;
import 'package:shelf_static/shelf_static.dart' as s_static;

s.Middleware createPackagesMiddleware(PackageMaps packageMaps) =>
    (s.Handler innerHandler) {
      return (s.Request request) {
        final filePath = request.url.path;
        final resolvedPath = packageMaps.resolvePackagePath(filePath);
        if (filePath == resolvedPath) {
          return innerHandler(request);
        }
        final reqUri = request.requestedUri;
        final newRequest = new s.Request(
            request.method,
            new Uri(
                scheme: reqUri.scheme,
                userInfo: reqUri.userInfo,
                host: reqUri.host,
                port: reqUri.port,
                path: path.basename(resolvedPath),
                query: reqUri.query),
            protocolVersion: request.protocolVersion,
            headers: request.headers,
            handlerPath: request.handlerPath,
            url: new Uri(path: path.basename(resolvedPath)),
            body: request.read(),
            encoding: request.encoding,
            context: request.context);
        final packageFileHandler = s_static.createStaticHandler(path.dirname(resolvedPath));
        final result = packageFileHandler(newRequest);
        return result;

      } as s.Handler;
    } as s.Middleware;

class PackageMaps {
  final io.Directory rootDirectory;

  PackageMaps(this.rootDirectory) {
    _buildPackagesMaps();
  }

  Map<String, io.Directory> packagesMapSource;

  void _buildPackagesMaps() {
    Map<String, Uri> packages = findPackagesFromFile(rootDirectory.uri).asMap();

    packagesMapSource = new Map<String, io.Directory>.fromIterable(
        packages.keys,
        key: (k) => k,
        value: (k) => new io.Directory.fromUri(packages[k]));
  }

  String resolvePackagePath(String filePath) {
    if (!filePath.contains('packages/')) {
      return filePath;
    }
    print(filePath);
    List<String> pathParts = path.split(filePath);
    final pos = pathParts.indexOf('packages') + 1;
    final packageDir = packagesMapSource[pathParts[pos]];
    pathParts = pathParts.getRange(pos + 1, pathParts.length).toList();
    //final packageFilePath =
    return    path.joinAll(path.split(packageDir.path)..addAll(pathParts));
//    return path.relative(packageFilePath, from: rootDirectory.path);
  }
}

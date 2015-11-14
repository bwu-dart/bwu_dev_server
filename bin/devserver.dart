library bwu_dev_server.bin.devserver;

import 'dart:async' show Future;
import 'package:bwu_dev_server/src/bin/main.dart' as m;

// TODO(zoechi) just export m instead of forwarding when WebStorm can handle it
// (WEB-15249)
Future main([List<String> args]) => m.main(args);

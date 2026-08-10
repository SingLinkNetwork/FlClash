import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:webdav_client/webdav_client.dart';

class DAVClient {
  late Client client;
  late String fileName;

  DAVClient(DAVProps dav) {
    client = newClient(dav.uri, user: dav.user, password: dav.password);
    // The dependency retries 302 responses itself, preserving WebDAV methods
    // and bodies, but does not recognize the equivalent permanent redirect.
    client.c.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.statusCode == HttpStatus.movedPermanently) {
            response.statusCode = HttpStatus.found;
          }
          handler.next(response);
        },
      ),
    );
    fileName = dav.fileName;
    client.setHeaders({'accept-charset': 'utf-8', 'Content-Type': 'text/xml'});
    client.setConnectTimeout(8000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
  }

  Future<bool> ping() async {
    try {
      await client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  String get root => '/$appName';

  String get backupFile => '$root/$fileName';

  Future<bool> backup(String localFilePath) async {
    await client.mkdir(root);
    await client.writeFromFile(localFilePath, backupFile);
    return true;
  }

  Future<bool> restore() async {
    await client.mkdir(root);
    final backupFilePath = await appPath.backupFilePath;
    await client.read2File(backupFile, backupFilePath);
    return true;
  }
}

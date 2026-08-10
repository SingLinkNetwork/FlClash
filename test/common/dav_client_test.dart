import 'dart:io';

import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  test(
    'follows a permanent WebDAV endpoint redirect when checking availability',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');
        if (request.uri.path == '/') {
          request.response
            ..statusCode = HttpStatus.movedPermanently
            ..headers.set(HttpHeaders.locationHeader, '/moved');
        } else if (request.uri.path == '/moved') {
          request.response.statusCode = HttpStatus.ok;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      try {
        final client = DAVClient(
          DAVProps(
            uri: 'http://${server.address.address}:${server.port}',
            user: 'user',
            password: 'password',
          ),
        );

        expect(await client.ping(), isTrue, reason: 'requests: $requests');
        expect(requests, ['OPTIONS /', 'OPTIONS /moved']);
      } finally {
        await server.close(force: true);
      }
    },
  );
}

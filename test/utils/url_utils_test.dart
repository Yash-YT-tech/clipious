import 'package:clipious/utils/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeInstanceUrl', () {
    test('trims whitespace', () {
      expect(normalizeInstanceUrl('  http://localhost:5566  '),
          'http://localhost:5566');
    });

    test('removes trailing slashes', () {
      expect(normalizeInstanceUrl('http://localhost:5566/'),
          'http://localhost:5566');
      expect(normalizeInstanceUrl('http://localhost:5566///'),
          'http://localhost:5566');
      expect(normalizeInstanceUrl('https://example.com/invidious/'),
          'https://example.com/invidious');
    });
  });

  group('addLocalProxyParameter', () {
    test('adds the parameter to a URL without a query', () {
      expect(addLocalProxyParameter('/api/manifest/dash/id/abc'),
          '/api/manifest/dash/id/abc?local=true');
    });

    test('appends to an existing query', () {
      expect(addLocalProxyParameter('/api/manifest/dash/id/abc?foo=bar'),
          '/api/manifest/dash/id/abc?foo=bar&local=true');
    });

    test('does not duplicate an existing local parameter', () {
      expect(addLocalProxyParameter('/x?local=true'), '/x?local=true');
      expect(addLocalProxyParameter('/x?local=1&a=b'), '/x?local=1&a=b');
    });

    test('leaves empty values unchanged', () {
      expect(addLocalProxyParameter(''), '');
    });
  });

  group('resolveInstanceUrl', () {
    const server = 'http://192.168.1.4:5566';

    test('keeps absolute URLs untouched', () {
      const url = 'https://rr5---sn.googlevideo.com/videoplayback?itag=18';
      expect(resolveInstanceUrl(server, url), url);
    });

    test('resolves absolute paths against the instance', () {
      expect(resolveInstanceUrl(server, '/api/manifest/dash/id/abc'),
          'http://192.168.1.4:5566/api/manifest/dash/id/abc');
      expect(resolveInstanceUrl(server, '/vi/abc/maxres.jpg'),
          'http://192.168.1.4:5566/vi/abc/maxres.jpg');
      expect(resolveInstanceUrl(server, '/videoplayback?itag=18&local=true'),
          'http://192.168.1.4:5566/videoplayback?itag=18&local=true');
    });

    test('resolves relative paths and keeps instance path prefix', () {
      expect(resolveInstanceUrl('https://example.com/invidious', 'vi/a.jpg'),
          'https://example.com/invidious/vi/a.jpg');
    });

    test('handles trailing slash on the instance URL', () {
      expect(resolveInstanceUrl('$server/', '/api/v1/stats'),
          'http://192.168.1.4:5566/api/v1/stats');
    });

    test('returns empty values unchanged', () {
      expect(resolveInstanceUrl(server, null), '');
      expect(resolveInstanceUrl(server, ''), '');
    });
  });
}

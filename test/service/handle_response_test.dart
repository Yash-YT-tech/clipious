import 'package:clipious/service.dart';
import 'package:clipious/settings/models/errors/invidious_service_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final service = Service();

  group('Service.handleResponse', () {
    test('returns decoded JSON for a successful response', () {
      final response = http.Response('{"name":"invidious"}', 200,
          headers: {'content-type': 'application/json'});

      expect(service.handleResponse(response), {'name': 'invidious'});
    });

    test('throws the server error message', () {
      final response = http.Response(
          '{"error":"Request must be authenticated"}', 403,
          headers: {'content-type': 'application/json'});

      expect(
          () => service.handleResponse(response),
          throwsA(isA<InvidiousServiceError>().having(
              (e) => e.message, 'message', 'Request must be authenticated')));
    });

    test('translates non JSON errors into InvidiousServiceError', () {
      final response = http.Response('<html>Bad gateway</html>', 502,
          headers: {'content-type': 'text/html'});

      expect(
          () => service.handleResponse(response),
          throwsA(isA<InvidiousServiceError>()
              .having((e) => e.message, 'message', contains('HTTP 502'))));
    });

    test('returns null for an empty successful response', () {
      final response = http.Response('', 204);

      expect(service.handleResponse(response), isNull);
    });

    test('throws for an empty unsuccessful response', () {
      final response = http.Response('', 500);

      expect(() => service.handleResponse(response),
          throwsA(isA<InvidiousServiceError>()));
    });
  });
}

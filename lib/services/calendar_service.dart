import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class CalendarService {
  CalendarService._private();
  static final CalendarService instance = CalendarService._private();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar'],
  );

  Future<String> insertEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    final account =
        _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently() ??
        await _googleSignIn.signIn();
    if (account == null) throw Exception('No Google user signed in');
    final headers = await account.authHeaders;
    final client = _AuthenticatedClient(headers);
    final api = gcal.CalendarApi(client);
    final event = gcal.Event()
      ..summary = title
      ..description = description
      ..start = (gcal.EventDateTime()
        ..dateTime = start
        ..timeZone = 'Asia/Ho_Chi_Minh')
      ..end = (gcal.EventDateTime()
        ..dateTime = end
        ..timeZone = 'Asia/Ho_Chi_Minh');
    final created = await api.events.insert(event, 'primary');
    return created.id ?? '';
  }

  Future<void> deleteEvent(String eventId) async {
    if (eventId.trim().isEmpty) return;
    final account =
        _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently() ??
        await _googleSignIn.signIn();
    if (account == null) throw Exception('No Google user signed in');
    final headers = await account.authHeaders;
    final client = _AuthenticatedClient(headers);
    final api = gcal.CalendarApi(client);
    await api.events.delete('primary', eventId);
  }
}

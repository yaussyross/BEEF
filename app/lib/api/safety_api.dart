import 'dart:math';

import 'http_client.dart';

enum ReportKind {
  harassment('harassment', 'Harassment'),
  impersonation('impersonation', 'Impersonation'),
  underage('underage', 'Underage user'),
  commercialSolicitation('commercial_solicitation', 'Commercial solicitation'),
  explicitContent('explicit_content', 'Explicit content'),
  csam('csam', 'Child sexual abuse material'),
  other('other', 'Other');

  const ReportKind(this.value, this.label);
  final String value;
  final String label;
}

/// Existing report categories and block semantics, without new moderation rules.
class SafetyApi {
  SafetyApi(this._client);
  final ApiClient _client;

  static String newReportId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> block(String userId) async {
    final data = await _client.post('/api/block', body: {'blocked_user_id': userId});
    if (data['ok'] != true || data['blocked'] != true) {
      throw const FormatException('Block was not confirmed');
    }
  }

  Future<void> report(String userId, ReportKind kind, String reason,
      {required String clientReportId, String? threadId}) async {
    final data = await _client.post('/api/report', body: {
      'client_report_id': clientReportId,
      'report_type': kind.value,
      'reason': reason.trim(),
      if (threadId == null) 'reported_user_id': userId,
      if (threadId != null) 'thread_id': threadId,
    });
    if (data['ok'] != true || data['report_id'] is! String) {
      throw const FormatException('Report was not confirmed');
    }
  }
}

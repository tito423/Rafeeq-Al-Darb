import 'dart:convert';
import 'dart:io';
void main() {
  final findings = <Map<String, Object>>[];
  final start = DateTime(2026, 10, 9, 20, 0).microsecondsSinceEpoch;
  for (var i=0; i<100000 && findings.length<3; i++) {
    final khatmaId = '${start+i}';
    final notificationId = 7000 + khatmaId.hashCode.abs() % 900;
    if ([7100,7200,7500].contains(notificationId) && !findings.any((r)=>r['notification_id']==notificationId)) {
      findings.add({'khatma_id':khatmaId,'notification_id':notificationId,'also_used_by': notificationId==7500?'quote reminder slot 0':notificationId==7100?'Fajr pre reminder':'Fajr post reminder'});
    }
  }
  final report = const JsonEncoder.withIndent('  ').convert({'scope':'Run the actual Dart string hash used by KhatmaStore; these are valid microsecond IDs producible by create(). No device alarm was modified.','collisions':findings});
  File('E:/My Projects/Rafiq-Al-Darb/docs/audits/evidence/2026-10-09/notification-id-collisions.json').writeAsStringSync(report);
  stdout.writeln(report);
}

import 'dart:convert';
import 'dart:io';

void main() async {
  final jsonFile = File('tm_audit/lib/models/preset_workers.json');
  final dartFile = File('tm_audit/lib/models/preset_workers.dart');

  final jsonString = await jsonFile.readAsString();
  final List<dynamic> workers = json.decode(jsonString);

  final buffer = StringBuffer();
  buffer.writeln("import 'worker.dart';");
  buffer.writeln();
  buffer.writeln('final List<Worker> presetWorkers = [');

  for (final worker in workers) {
    final userId = _escape(worker['userId']);
    final name = _escape(worker['name']);
    final companies =
        (worker['companies'] as List).map((c) => "'${_escape(c)}'").join(', ');
    final status = _escape(worker['status']);
    final ic = _escape(worker['ic']);
    buffer.writeln(
        "  Worker(userId: '$userId', name: '$name', companies: [$companies], status: '$status', ic: '$ic'),");
  }

  buffer.writeln('];');

  await dartFile.writeAsString(buffer.toString());
  stdout.writeln('preset_workers.dart generated successfully.');
}

String _escape(String? input) {
  if (input == null) return '';
  return input.replaceAll("'", "\\'");
}

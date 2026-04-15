import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import '../models/document.dart';
import '../services/data_encryption_service.dart';

class ExcelService {
  Future<bool> _checkAndRequestPermissions() async {
    // Check storage permissions
    var status = await Permission.storage.status;
    if (status.isDenied) {
      status = await Permission.storage.request();
    }

    // For Android 11+ (API 30+), also check manage external storage
    if (Platform.isAndroid) {
      var manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isDenied) {
        manageStatus = await Permission.manageExternalStorage.request();
      }
      return status.isGranted && manageStatus.isGranted;
    }

    return status.isGranted;
  }

  Future<String> exportAuditToExcel(String documentId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query('documents',
        where: 'id = ?', whereArgs: [documentId], limit: 1);
    if (result.isEmpty) throw Exception('Document not found');
    final doc = Document.fromMap(result.first);

    // Create Excel workbook
    final excel = Excel.createExcel();

    // Remove the default 'Sheet1'
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Fetch teams for this document and sort them: CM first, then 2ND LEVEL, then others, all by number
    final teamRowsRaw = await db
        .query('teams', where: 'documentId = ?', whereArgs: [documentId]);
    List<Map<String, dynamic>> teamRows =
        List<Map<String, dynamic>>.from(teamRowsRaw);

    int teamSortKey(Map<String, dynamic> t) {
      final label = (t['label'] ?? '').toString().toUpperCase();
      final number = t['number'] is int
          ? t['number'] as int
          : int.tryParse(t['number']?.toString() ?? '') ?? 0;
      if (label.startsWith('CM')) return 0 * 1000 + number;
      if (label.startsWith('2ND LEVEL')) return 1 * 1000 + number;
      return 2 * 1000 + number;
    }

    teamRows.sort((a, b) => teamSortKey(a).compareTo(teamSortKey(b)));

    final Map<String, String> teamIdToLabel = {
      for (final t in teamRows) t['id'] as String: (t['label'] ?? '').toString()
    };

    // Get summary_team for this document only (filter by teamId), and order by teamRows order
    final summaryTeamsAll = await db.query('summary_team');
    final teamIds = teamRows.map((t) => t['id']).toList();
    final summaryTeamsMap = {
      for (final st in summaryTeamsAll)
        if (teamIds.contains(st['teamId'])) st['teamId']: st
    };
    final summaryTeams = [
      for (final id in teamIds)
        if (summaryTeamsMap.containsKey(id)) summaryTeamsMap[id]!
    ];

    // Load company_name table for attachments, members, and remarks
    final companyNameRows = await db.query('company_name');
    final Map<String, Map<String, dynamic>> companyNameData = {
      for (final row in companyNameRows) row['teamId'] as String: row
    };

    // Load finding_summary
    final findingResult = await db.query('finding_summary',
        where: 'documentId = ?', whereArgs: [documentId], limit: 1);
    // Get and decrypt remark if needed
    String remark = '';
    if (findingResult.isNotEmpty && findingResult.first['remark'] is String) {
      final remarkData = findingResult.first['remark'] as String;
      if (remarkData.isNotEmpty) {
        // Try to decrypt the remark if it's encrypted
        try {
          remark = await DataEncryptionService.decryptData(remarkData);
        } catch (_) {
          remark = remarkData; // Use as-is if decryption fails
        }
      }
    }

    // --- Sheet 1: Cover Page Info ---
    final coverSheet = excel['Cover Page'];
    coverSheet.appendRow(['CM TEAM COMPLIANCE']);
    coverSheet.appendRow([]);
    coverSheet.appendRow(['Date:', _formatDate(doc.lastModified)]);
    coverSheet.appendRow(['Audit Type:', doc.type]);
    coverSheet.appendRow(['Company Name:', doc.companyName]);
    coverSheet.appendRow(['Location:', doc.location]);
    coverSheet.appendRow(['Auditor:', doc.auditor]);
    // Autofit columns for Cover Page
    for (int col = 0; col < 2; col++) {
      coverSheet.setColAutoFit(col);
    }

    // --- Sheet 2: Profiling Team ---
    final profilingSheet = excel['Profiling Team'];
    final headerRow = [
      'No',
      'Team',
      'ATTENDANCE',
      'Name',
      'IC No (no hyphen)',
      'NTSMP EXPIRY DATE',
      'AESP EXPIRY DATE',
      'AGTES EXPIRY DATE',
      'POLE PROFICIENCY',
      'CA2A EXPIRY DATE',
      'CA2C EXPIRY DATE',
    ];
    final columnWidths = [
      5.0,
      12.0,
      18.0,
      22.0,
      18.0,
      18.0,
      18.0,
      18.0,
      12.0,
      18.0,
      18.0
    ];
    for (int col = 0; col < columnWidths.length; col++) {
      profilingSheet.setColWidth(col, columnWidths[col]);
    }
    profilingSheet.appendRow(headerRow);
    for (int col = 0; col < headerRow.length; col++) {
      final cell = profilingSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = CellStyle(
        backgroundColorHex: '#FFC000',
        fontFamily: getFontFamily(FontFamily.Arial),
        bold: true,
      );
    }
    int currentRow = 1;
    for (final team in teamRows) {
      // Optional: Insert a separator row with the team name
      profilingSheet
          .appendRow([team['label'], ...List.filled(headerRow.length - 1, '')]);
      currentRow++;
      // Fetch all members for this team, ordered by personIndex ASC
      final members = await db.query('profiling_team',
          where: 'teamId = ?',
          whereArgs: [team['id']],
          orderBy: 'personIndex ASC');
      for (int i = 0; i < members.length; i++) {
        final row = members[i];

        // Decrypt sensitive fields (name and IC)
        final decryptedRow =
            await DataEncryptionService.decryptSensitiveFields(row);

        String name = (decryptedRow['name'] ?? '').toString();
        String ic = (decryptedRow['ic'] ?? '').toString().replaceAll('-', '');
        String attendance = (row['attendance'] ?? '').toString().toUpperCase();
        final ntsmpDate = row['ntsmpDate'];
        final aespDate = row['aespDate'];
        final agtesDate = row['agtesDate'];
        final ca2aDate = row['ca2aDate'];
        final ca2cDate = row['ca2cDate'];
        String ntsmp = _formatDateWithExpiryCheck(ntsmpDate, doc.createdDate);
        String aesp = _formatDateWithExpiryCheck(aespDate, doc.createdDate);
        String agtes = _formatDateWithExpiryCheck(agtesDate, doc.createdDate);
        String pole = (row['poleProficiency'] ?? '').toString().toUpperCase();
        String poleDisplay = (pole == 'YES') ? '✓' : '';
        String ca2a = _formatDateWithExpiryCheck(ca2aDate, doc.createdDate);
        String ca2c = _formatDateWithExpiryCheck(ca2cDate, doc.createdDate);
        bool isNtsmpExpired = _isDateExpired(ntsmpDate, doc.createdDate);
        bool isAespExpired = _isDateExpired(aespDate, doc.createdDate);
        bool isAgtesExpired = _isDateExpired(agtesDate, doc.createdDate);
        bool isCa2aExpired = _isDateExpired(ca2aDate, doc.createdDate);
        bool isCa2cExpired = _isDateExpired(ca2cDate, doc.createdDate);
        final attendanceText =
            attendance == 'NOT PRESENT' ? 'DID NOT PRESENT' : attendance;
        final rowData = [
          (i + 1).toString(),
          team['label'],
          attendanceText,
          name,
          ic,
          ntsmp,
          aesp,
          agtes,
          poleDisplay,
          ca2a,
          ca2c,
        ];
        profilingSheet.appendRow(rowData);
        // Set red font for expired cells
        if (isNtsmpExpired) {
          profilingSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 5, rowIndex: currentRow))
              .cellStyle = CellStyle(fontColorHex: '#E53935');
        }
        if (isAespExpired) {
          profilingSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 6, rowIndex: currentRow))
              .cellStyle = CellStyle(fontColorHex: '#E53935');
        }
        if (isAgtesExpired) {
          profilingSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 7, rowIndex: currentRow))
              .cellStyle = CellStyle(fontColorHex: '#E53935');
        }
        if (isCa2aExpired) {
          profilingSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 9, rowIndex: currentRow))
              .cellStyle = CellStyle(fontColorHex: '#E53935');
        }
        if (isCa2cExpired) {
          profilingSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 10, rowIndex: currentRow))
              .cellStyle = CellStyle(fontColorHex: '#E53935');
        }
        currentRow++;
      }
    }

    // Remove Sheet1 and FINDING & SUMMARY after all sheets are created
    if (excel.sheets.containsKey('Sheet1')) {
      try {
        excel.delete('Sheet1');
      } catch (_) {
        // Ignore if already deleted or unmodifiable
      }
    }
    if (excel.sheets.containsKey('FINDING & SUMMARY')) {
      try {
        excel.delete('FINDING & SUMMARY');
      } catch (_) {
        // Ignore if already deleted or unmodifiable
      }
    }

    // --- Sheet 3: Summary Team ---
    final summarySheet = excel['Summary Team'];
    summarySheet
        .appendRow(['SUMMARY BY TEAM ${doc.type} – ${doc.companyName}']);
    summarySheet.appendRow([]);

    // Header row
    summarySheet.appendRow(['TEAM', 'COMPETENCY', 'TYPE OF TEAM', 'PPE']);

    // Data rows
    for (final team in summaryTeams) {
      final competency = (team['competency'] ?? '').toString().trim();
      final isNotCompetent = competency.toLowerCase().contains('not') &&
          competency.toLowerCase().contains('competent');
      final competencyDisplay = isNotCompetent ? 'X' : '✓';

      final typeOfTeam = (team['typeOfTeam'] ?? '').toString();
      final teamId = team['teamId'] ?? '';
      final teamLabel = teamIdToLabel[teamId] ?? teamId.toString();

      summarySheet.appendRow([
        teamLabel,
        competencyDisplay,
        typeOfTeam,
        (team['ppe'] ?? '').toString(),
      ]);
    }

    // --- Sheet 4: Company Name Data ---
    final companySheet = excel['Company Name Data'];
    companySheet
        .appendRow(['${doc.type} TEAM ${doc.companyName.toUpperCase()}']);
    companySheet.appendRow([]);

    // Header row
    companySheet.appendRow(['Team', 'Team Members', 'Remark', 'Has Image']);

    // Data rows
    for (final team in teamRows) {
      final teamId = team['id'] as String;
      final teamLabel = team['label'] as String;
      final companyData = companyNameData[teamId];

      // Get team members
      List<String> memberNames = [];
      if (companyData != null &&
          companyData['members'] is String &&
          (companyData['members'] as String).isNotEmpty) {
        // Try to decrypt members if it's encrypted
        String membersData = companyData['members'] as String;
        try {
          membersData = await DataEncryptionService.decryptData(membersData);
        } catch (_) {
          // Use as-is if decryption fails
        }

        memberNames = membersData
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      // Fallback if all values are empty
      if (memberNames.isEmpty) {
        final members = await db.query('profiling_team',
            where: 'teamId = ?',
            whereArgs: [teamId],
            orderBy: 'personIndex ASC');

        // Decrypt member names
        List<String> decryptedNames = [];
        for (final member in members) {
          final decryptedMember =
              await DataEncryptionService.decryptSensitiveFields(member);
          final name = (decryptedMember['name'] ?? '').toString();
          if (name.isNotEmpty) {
            decryptedNames.add(name);
          }
        }
        memberNames = decryptedNames;
      }

      // Get remark (decrypt if needed)
      String remark = '';
      if (companyData != null && companyData['remark'] is String) {
        final remarkData = companyData['remark'] as String;
        if (remarkData.isNotEmpty) {
          // Try to decrypt the remark if it's encrypted
          try {
            remark = await DataEncryptionService.decryptData(remarkData);
          } catch (_) {
            remark = remarkData; // Use as-is if decryption fails
          }
        }
      }

      // Check if has image
      final hasImage = companyData != null &&
          companyData['attachmentPath'] is String &&
          (companyData['attachmentPath'] as String).isNotEmpty;

      companySheet.appendRow([
        teamLabel,
        memberNames.join(', '),
        remark,
        hasImage ? 'Yes' : 'No',
      ]);
    }

    // --- Sheet 5: Finding & Summary ---
    final findingSheet = excel['Finding & Summary'];
    findingSheet.appendRow(['FINDING AND SUMMARY']);
    findingSheet.appendRow([]);

    if (remark.isNotEmpty) {
      final lines = remark.split('\n');
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          findingSheet.appendRow([line.trim()]);
        }
      }
    }

    findingSheet.appendRow([]);
    findingSheet.appendRow(['THANK YOU.']);

    // Save the Excel file to Downloads folder
    final fileName =
        'audit_${doc.companyName}_${_formatDateForFileName(doc.lastModified)}.xlsx';

    // Try to save to Downloads folder first, fallback to app documents
    String filePath;
    try {
      // Check permissions first
      final hasPermissions = await _checkAndRequestPermissions();

      if (hasPermissions) {
        // For Android, try to save to Downloads folder
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          filePath = '${downloadsDir.path}/$fileName';
        } else {
          // Fallback to app documents directory
          final dir = await getApplicationDocumentsDirectory();
          filePath = '${dir.path}/$fileName';
        }
      } else {
        // No permissions, save to app documents
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileName';
      }
    } catch (e) {
      // Fallback to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      filePath = '${dir.path}/$fileName';
    }

    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    return filePath;
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month]} ${date.year}';
  }

  String _formatDateForFileName(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  // New method to format dates with expired status
  String _formatDateWithExpiryCheck(dynamic dateStr, DateTime auditDate) {
    if (dateStr == null || dateStr.toString().isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr);
      final formattedDate =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

      // Check if date is expired (older than audit date)
      if (d.isBefore(auditDate)) {
        return 'EXPIRED $formattedDate';
      }
      return formattedDate;
    } catch (_) {
      return dateStr.toString();
    }
  }

  // Helper method to check if a date is expired
  bool _isDateExpired(dynamic dateStr, DateTime auditDate) {
    if (dateStr == null || dateStr.toString().isEmpty) return false;
    try {
      final d = DateTime.parse(dateStr);
      return d.isBefore(auditDate);
    } catch (_) {
      return false;
    }
  }

  // Get the file path for sharing (returns the actual saved file path)
  Future<String> getExcelFilePath(String documentId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query('documents',
        where: 'id = ?', whereArgs: [documentId], limit: 1);
    if (result.isEmpty) throw Exception('Document not found');
    final doc = Document.fromMap(result.first);

    final fileName =
        'audit_${doc.companyName}_${_formatDateForFileName(doc.lastModified)}.xlsx';

    // Check if file already exists in Downloads
    final downloadsPath = '/storage/emulated/0/Download/$fileName';
    final downloadsFile = File(downloadsPath);
    if (await downloadsFile.exists()) {
      return downloadsPath;
    }

    // Check if file exists in app documents
    final dir = await getApplicationDocumentsDirectory();
    final appPath = '${dir.path}/$fileName';
    final appFile = File(appPath);
    if (await appFile.exists()) {
      return appPath;
    }

    // If file doesn't exist, generate it
    return await exportAuditToExcel(documentId);
  }
}

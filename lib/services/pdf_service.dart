import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/document.dart';
// import 'pdf_summary_page.dart';
// import 'dart:typed_data';
import '../services/data_encryption_service.dart';

class PdfService {
  Future<Uint8List> generateFullAuditPdf(String documentId) async {
    final stopwatch = Stopwatch()..start();
    final db = await DatabaseHelper().database;
    final result = await db.query('documents',
        where: 'id = ?', whereArgs: [documentId], limit: 1);
    if (result.isEmpty) throw Exception('Document not found');
    final doc = Document.fromMap(result.first);

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

    final pdf = pw.Document();
    final dateStr = _formatDate(doc.createdDate);

    // Use the raw company_left_logo.png for the left side
    final leftLogoBytes = await imageFromAssetBundle('assets/cover_photo.png');
    final tmLogoBytes = await imageFromAssetBundle('assets/tm_logo.png');
    final appIconBytes = await imageFromAssetBundle('assets/app_icon.png');
    final companyLeftLogoBytes =
        await imageFromAssetBundle('assets/company_left_logo.png');
    final notoFont =
        pw.Font.ttf(await rootBundle.load('assets/NotoSans-Regular.ttf'));
    final montserratBold =
        pw.Font.ttf(await rootBundle.load('assets/Montserrat-Bold.ttf'));

    // --- Cover Page (no page number) ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Left: Raw company logo image
              pw.Container(
                width: PdfPageFormat.a4.landscape.width * 0.5,
                child: pw.Image(pw.MemoryImage(leftLogoBytes),
                    fit: pw.BoxFit.cover),
              ),
              // Right: TM logo, title, and audit info
              pw.Container(
                width: PdfPageFormat.a4.landscape.width * 0.5,
                padding: pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Image(pw.MemoryImage(tmLogoBytes), width: 120),
                      ],
                    ),
                    pw.SizedBox(height: 60),
                    pw.Text(
                      'CM TEAM COMPLIANCE',
                      style: pw.TextStyle(
                        font: montserratBold,
                        fontSize: 36,
                        color: PdfColor.fromInt(0xff0033cc),
                      ),
                    ),
                    pw.Spacer(),
                    pw.Container(
                      margin: pw.EdgeInsets.only(top: 40),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Date: $dateStr',
                            style: pw.TextStyle(
                                font: notoFont,
                                fontSize: 20,
                                color: PdfColor.fromInt(0xff0033cc)),
                          ),
                          pw.Text(
                            'Audit ${doc.type} ${doc.companyName}',
                            style: pw.TextStyle(
                                font: notoFont,
                                fontSize: 20,
                                color: PdfColor.fromInt(0xff0033cc)),
                          ),
                          pw.Text(
                            'Location: ${doc.location}',
                            style: pw.TextStyle(
                                font: notoFont,
                                fontSize: 20,
                                color: PdfColor.fromInt(0xff0033cc)),
                          ),
                          pw.Text(
                            'Auditor: ${doc.auditor}',
                            style: pw.TextStyle(
                                font: notoFont,
                                fontSize: 20,
                                color: PdfColor.fromInt(0xff0033cc)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // --- Page number counter (start at 2 after cover) ---
    int pageNumber = 2;

    // --- Profiling Team Pages (chunked, with page number) ---
    // Pre-build all team tables and rows
    final orange = PdfColor.fromInt(0xffffc000); // Header color
    final borderColor = PdfColor.fromInt(0xff000000);
    final headerStyle = pw.TextStyle(
        font: montserratBold, fontSize: 7, color: PdfColor.fromInt(0xff000000));
    // Use DejaVuSans for tick support
    final dejaVuFont =
        pw.Font.ttf(await rootBundle.load('assets/DejaVuSans.ttf'));
    final cellStyle = pw.TextStyle(
        font: notoFont,
        fontSize: 6,
        color: PdfColor.fromInt(0xff000000),
        fontFallback: [dejaVuFont]);
    final cellStyleRed = pw.TextStyle(
        font: notoFont,
        fontSize: 6,
        color: PdfColor.fromInt(0xffe53935),
        fontFallback: [dejaVuFont]);
    List<pw.Widget> teamTables = [];
    for (final team in teamRows) {
      final teamId = team['id'] as String;
      final teamLabel = team['label'] as String;
      final List<pw.TableRow> rows = [];
      for (int i = 1; i <= 10; i++) {
        final person = await db.query('profiling_team',
            where: 'teamId = ? AND personIndex = ?',
            whereArgs: [teamId, i],
            limit: 1);
        if (person.isNotEmpty) {
          final row = person.first;

          // Decrypt sensitive fields (name and IC)
          final decryptedRow =
              await DataEncryptionService.decryptSensitiveFields(row);

          String name = (decryptedRow['name'] ?? '').toString();
          String ic = (decryptedRow['ic'] ?? '').toString().replaceAll('-', '');
          String attendance =
              (row['attendance'] ?? '').toString().toUpperCase();

          // Get dates and check if expired
          final ntsmpDate = row['ntsmpDate'];
          final aespDate = row['aespDate'];
          final agtesDate = row['agtesDate'];
          final ca2aDate = row['ca2aDate'];
          final ca2cDate = row['ca2cDate'];

          String ntsmp = _formatDateWithExpiryCheck(ntsmpDate, doc.createdDate);
          String aesp = _formatDateWithExpiryCheck(aespDate, doc.createdDate);
          String agtes = _formatDateWithExpiryCheck(agtesDate, doc.createdDate);
          String pole = (row['poleProficiency'] ?? '').toString().toUpperCase();
          // Use tick for pole proficiency if 'YES'
          String poleDisplay = (pole == 'YES') ? '✓' : '';
          String ca2a = _formatDateWithExpiryCheck(ca2aDate, doc.createdDate);
          String ca2c = _formatDateWithExpiryCheck(ca2cDate, doc.createdDate);

          // Check if dates are expired for red styling
          bool isNtsmpExpired = _isDateExpired(ntsmpDate, doc.createdDate);
          bool isAespExpired = _isDateExpired(aespDate, doc.createdDate);
          bool isAgtesExpired = _isDateExpired(agtesDate, doc.createdDate);
          bool isCa2aExpired = _isDateExpired(ca2aDate, doc.createdDate);
          bool isCa2cExpired = _isDateExpired(ca2cDate, doc.createdDate);

          // If attendance is 'NOT PRESENT', set all cells to red and attendance to 'DID NOT PRESENT'
          final isNotPresent = attendance == 'NOT PRESENT';
          final rowStyle = isNotPresent ? cellStyleRed : cellStyle;
          final attendanceText = isNotPresent ? 'DID NOT PRESENT' : attendance;

          rows.add(pw.TableRow(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(i.toString(),
                    style: rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child:
                    pw.Text(teamLabel, style: rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(attendanceText,
                    style: rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(name, style: rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(ic, style: rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(ntsmp,
                    style: isNtsmpExpired
                        ? cellStyleRed.copyWith(fontSize: 5)
                        : rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(aesp,
                    style: isAespExpired
                        ? cellStyleRed.copyWith(fontSize: 5)
                        : rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(agtes,
                    style: isAgtesExpired
                        ? cellStyleRed.copyWith(fontSize: 5)
                        : rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child:
                    pw.Text(poleDisplay, style: rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(ca2a,
                    style: isCa2aExpired
                        ? cellStyleRed.copyWith(fontSize: 5)
                        : rowStyle.copyWith(fontSize: 5)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.all(2),
                child: pw.Text(ca2c,
                    style: isCa2cExpired
                        ? cellStyleRed.copyWith(fontSize: 5)
                        : rowStyle.copyWith(fontSize: 5)),
              ),
            ],
          ));
        }
      }
      // Table header (all centered)
      final header = pw.TableRow(
        decoration: pw.BoxDecoration(color: orange),
        children: [
          for (final col in [
            'No',
            'Team',
            'ATTENDANCE',
            'Name',
            'IC No (no hyphen) (Please specify)',
            'NTSMP EXPIRY DATE',
            'AESP EXPIRY DATE',
            'AGTES EXPIRY DATE',
            'POLE PROFICIENCY',
            'CA2A EXPIRY DATE',
            'CA2C EXPIRY DATE',
          ])
            pw.Container(
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.all(2),
              child: pw.Text(col, style: headerStyle.copyWith(fontSize: 6)),
            ),
        ],
      );
      teamTables.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 1),
              columnWidths: {
                0: pw.FlexColumnWidth(0.7), // No
                1: pw.FlexColumnWidth(2), // Team
                2: pw.FlexColumnWidth(2), // Attendance
                3: pw.FlexColumnWidth(4), // Name
                4: pw.FlexColumnWidth(2.5), // IC
                5: pw.FlexColumnWidth(2), // NTSMP
                6: pw.FlexColumnWidth(2), // AESP
                7: pw.FlexColumnWidth(2), // AGTES
                8: pw.FlexColumnWidth(2), // Pole
                9: pw.FlexColumnWidth(2), // CA2A
                10: pw.FlexColumnWidth(2), // CA2C
              },
              children: [header, ...rows],
            ),
            pw.SizedBox(height: 6), // Small gap between tables
          ],
        ),
      );
    }

    // Group team tables into pages of 6
    const teamsPerPage = 6;
    for (int i = 0; i < teamTables.length; i += teamsPerPage) {
      final tablesOnPage = teamTables.sublist(
          i,
          (i + teamsPerPage > teamTables.length)
              ? teamTables.length
              : i + teamsPerPage);
      final thisPageNumber = pageNumber;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.SizedBox(height: 8),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PROFILING TEAM ${doc.type} – ${doc.companyName.toUpperCase()}',
                          style: pw.TextStyle(
                            font: montserratBold,
                            fontSize: 16,
                            color: PdfColor.fromInt(0xff000000),
                          ),
                        ),
                        pw.Spacer(),
                        pw.Image(pw.MemoryImage(tmLogoBytes), width: 80),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    ...tablesOnPage,
                    pw.Spacer(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(thisPageNumber.toString(),
                            style: pw.TextStyle(font: notoFont, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      pageNumber++;
    }

    // --- Summary Team Page (with page number) ---
    final summaryPageNumber = pageNumber;
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        build: (pw.Context context) {
          return buildSummaryTeamPage(
            summaryTeams: summaryTeams,
            teamType: doc.type,
            companyName: doc.companyName,
            montserratBold: montserratBold,
            notoFont: notoFont,
            dejaVuFont: dejaVuFont,
            tmLogoBytes: tmLogoBytes,
            pageNumber: summaryPageNumber,
            teamIdToLabel: teamIdToLabel,
          );
        },
      ),
    );
    pageNumber++;

    // --- Add Company Name Pages (after Summary Team page) ---
    int companyPageNumber = pageNumber;

    // Preload all team images, members, and remarks for this document
    Map<String, Uint8List?> teamIdToImageBytes = {};
    Map<String, List<String>> teamIdToMemberNames = {};
    Map<String, String?> teamIdToRemark = {};

    // Load company_name table for attachments, members, and remarks
    final companyNameRows = await db.query('company_name');
    final Map<String, Map<String, dynamic>> companyNameData = {
      for (final row in companyNameRows) row['teamId'] as String: row
    };

    for (final team in teamRows) {
      final teamId = team['id'] as String;
      final companyData = companyNameData[teamId];

      // Load team image (attachmentPath from company_name)
      Uint8List? imageBytes;
      if (companyData != null &&
          companyData['attachmentPath'] is String &&
          (companyData['attachmentPath'] as String).isNotEmpty) {
        try {
          final file = File(companyData['attachmentPath'] as String);
          if (await file.exists()) {
            imageBytes = await file.readAsBytes();
          } else {
            imageBytes = await imageFromAssetBundle(
                companyData['attachmentPath'] as String);
          }
        } catch (_) {
          imageBytes = null;
        }
      }
      teamIdToImageBytes[teamId] = imageBytes;

      // Get team members from company_name.members (split by '|'), fallback to profiling_team if empty or all values are empty
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
      teamIdToMemberNames[teamId] = memberNames;

      // Load remark (decrypt if needed)
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
      teamIdToRemark[teamId] = remark;
    }

    // Prepare team cards (grouped by 3 per page)
    List<List<Map<String, dynamic>>> teamGroups = [];
    for (int i = 0; i < teamRows.length; i += 3) {
      teamGroups.add(teamRows.sublist(
          i, (i + 3 > teamRows.length) ? teamRows.length : i + 3));
    }

    for (final group in teamGroups) {
      final thisPageNumber = companyPageNumber;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // Company left logo and company name title at top left
                pw.Positioned(
                  left: 0,
                  top: 60,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 120,
                        height: 48,
                        child: pw.Image(pw.MemoryImage(companyLeftLogoBytes),
                            fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Text(
                        '${doc.type} TEAM ${doc.companyName.toUpperCase()}',
                        style: pw.TextStyle(
                          font: montserratBold,
                          fontSize: 32,
                          color: PdfColor.fromInt(0xff0033cc),
                        ),
                      ),
                    ],
                  ),
                ),
                // TM logo at top right
                pw.Positioned(
                  right: 0,
                  top: 0,
                  child: pw.Image(pw.MemoryImage(tmLogoBytes), width: 80),
                ),
                // Blue bar at the bottom
                pw.Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: pw.Container(
                    height: 32,
                    color: PdfColor.fromInt(0xff0033cc),
                  ),
                ),
                // Page number inside the blue bar, right aligned and vertically centered
                pw.Positioned(
                  right: 48,
                  bottom: 8, // Lowered to sit inside the blue bar
                  child: pw.Text(
                    thisPageNumber.toString(),
                    style: pw.TextStyle(
                        font: notoFont, fontSize: 16, color: PdfColors.white),
                  ),
                ),
                // Cards row (up to 3), add gap between cards
                pw.Padding(
                  padding: pw.EdgeInsets.only(
                    left: 32, // reduced left margin for card group (was 152)
                    right: 32, // right margin for card group
                    top: 120, // lower to make space for logo+title
                    bottom: 56, // increased bottom padding to avoid blue bar
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      for (int i = 0; i < group.length; i++) ...[
                        if (i > 0) pw.SizedBox(width: 24), // gap between cards
                        pw.Expanded(
                          child: buildTeamCard(
                            group[i],
                            teamIdToImageBytes[group[i]['id'] as String],
                            teamIdToMemberNames[group[i]['id'] as String] ?? [],
                            teamIdToRemark[group[i]['id'] as String] ?? '',
                            appIconBytes,
                            notoFont,
                            montserratBold,
                            borderWidth: 3.0, // Thicker border
                          ),
                        ),
                      ],
                      if (group.length < 3)
                        for (int i = 0; i < 3 - group.length; i++)
                          pw.Expanded(child: pw.Container()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
      companyPageNumber++;
      pageNumber++;
    }

    // Add Finding & Summary page as the last page (no page number)
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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Main content: Title, remark, THANK YOU
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 12),
                  pw.Center(
                    child: pw.Text(
                      'FINDING AND SUMMARY',
                      style: pw.TextStyle(
                        font: montserratBold,
                        fontSize: 32,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  _buildFindingSummaryRemark(remark, notoFont, montserratBold),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'THANK YOU.',
                    style: pw.TextStyle(
                      font: notoFont, // Not bold
                      fontSize: 18,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
              // Static footer: company name and TM logo at bottom left
              pw.Positioned(
                left: 0,
                bottom: 36, // match vertical margin
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TM Technology Services Sdn Bhd',
                      style: pw.TextStyle(
                        font: notoFont,
                        fontSize: 18,
                        color: PdfColor.fromInt(0xff0033cc), // blue
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Image(pw.MemoryImage(tmLogoBytes), width: 120),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    stopwatch.stop();
    print('\n================ PERFORMANCE METRIC ================');
    print('Task: Full Audit PDF Generation');
    print('Document ID: $documentId');
    print('Execution Time: ${stopwatch.elapsedMilliseconds} ms (${stopwatch.elapsedMilliseconds / 1000} seconds)');
    print('====================================================\n');
    return pdfBytes;
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
      // Only return true if the date is before the audit date (expired)
      return d.isBefore(auditDate);
    } catch (_) {
      return false;
    }
  }

  // Add this method to PdfService
  Future<Uint8List> generateFindingSummaryPage(String documentId) async {
    final db = await DatabaseHelper().database;
    final docResult = await db.query('documents',
        where: 'id = ?', whereArgs: [documentId], limit: 1);
    if (docResult.isEmpty) throw Exception('Document not found');
    // final doc = Document.fromMap(docResult.first);
    final tmLogoBytes = await imageFromAssetBundle('assets/tm_logo.png');
    final notoFont =
        pw.Font.ttf(await rootBundle.load('assets/NotoSans-Regular.ttf'));
    final montserratBold =
        pw.Font.ttf(await rootBundle.load('assets/Montserrat-Bold.ttf'));
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Main content: Title, remark, THANK YOU
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 12),
                  pw.Center(
                    child: pw.Text(
                      'FINDING AND SUMMARY',
                      style: pw.TextStyle(
                        font: montserratBold,
                        fontSize: 32,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  _buildFindingSummaryRemark(remark, notoFont, montserratBold),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'THANK YOU.',
                    style: pw.TextStyle(
                      font: notoFont, // Not bold
                      fontSize: 18,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
              // Static footer: company name and TM logo at bottom left
              pw.Positioned(
                left: 0,
                bottom: 36, // match vertical margin
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TM Technology Services Sdn Bhd',
                      style: pw.TextStyle(
                        font: notoFont,
                        fontSize: 18,
                        color: PdfColor.fromInt(0xff0033cc), // blue
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Image(pw.MemoryImage(tmLogoBytes), width: 120),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // Helper to build the rich remark section for Finding & Summary
  pw.Widget _buildFindingSummaryRemark(
      String remark, pw.Font notoFont, pw.Font montserratBold) {
    // For now, highlight 'NOT COMPLY' and 'NOT PRESENT' in red, rest in black.
    // In the future, you can parse for custom tags for more flexible coloring.
    final lines = remark.split('\n');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Numbering for each line if it starts with a number (like the sample)
                  if (RegExp(r'^[0-9]+[.)]').hasMatch(line.trim()))
                    pw.Text(
                      '${line.trim().split(' ')[0]} ',
                      style: pw.TextStyle(
                          font: notoFont, fontSize: 16, color: PdfColors.black),
                    ),
                  pw.Expanded(
                    child: _buildFindingSummaryLine(
                      // Remove the number prefix for the main text
                      RegExp(r'^[0-9]+[.)] ?').hasMatch(line.trim())
                          ? line
                              .trim()
                              .replaceFirst(RegExp(r'^[0-9]+[.)] ?'), '')
                          : line,
                      notoFont,
                      montserratBold,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  pw.Widget _buildFindingSummaryLine(
      String line, pw.Font notoFont, pw.Font montserratBold) {
    // Highlight specific words in red: NOT COMPLY, NOT PRESENT, NOT COMPETENT, ALERT, URGENT
    final redWords = [
      'NOT COMPLY',
      'NOT PRESENT',
      'NOT COMPETENT',
      'ALERT',
      'URGENT'
    ];
    final spans = <pw.InlineSpan>[];
    String working = line;
    while (working.isNotEmpty) {
      int minIndex = working.length;
      String? found;
      for (final word in redWords) {
        final idx = working.indexOf(word);
        if (idx >= 0 && idx < minIndex) {
          minIndex = idx;
          found = word;
        }
      }
      if (found != null && minIndex < working.length) {
        spans.add(pw.TextSpan(
          text: working.substring(0, minIndex),
          style: pw.TextStyle(
              font: notoFont, fontSize: 16, color: PdfColors.black),
        ));
        spans.add(pw.TextSpan(
          text: found,
          style:
              pw.TextStyle(font: notoFont, fontSize: 16, color: PdfColors.red),
        ));
        working = working.substring(minIndex + found.length);
      } else {
        spans.add(pw.TextSpan(
          text: working,
          style: pw.TextStyle(
              font: notoFont, fontSize: 16, color: PdfColors.black),
        ));
        break;
      }
    }
    return pw.RichText(text: pw.TextSpan(children: spans));
  }
}

Future<Uint8List> imageFromAssetBundle(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List();
}

pw.Widget buildSummaryTeamPage({
  required List<Map<String, dynamic>> summaryTeams,
  required String teamType,
  required String companyName,
  required pw.Font montserratBold,
  required pw.Font notoFont,
  required pw.Font dejaVuFont,
  required Uint8List tmLogoBytes,
  required int pageNumber,
  required Map<String, String> teamIdToLabel, // <-- add this param
}) {
  final green = PdfColor.fromInt(0xff99cc66);
  final borderColor = PdfColor.fromInt(0xff000000);

  final headerStyle = pw.TextStyle(
    font: montserratBold,
    fontSize: 14,
    color: PdfColor.fromInt(0xff000000),
  );
  final cellStyle = pw.TextStyle(
    font: notoFont,
    fontSize: 10,
    color: PdfColor.fromInt(0xff000000),
    fontFallback: [dejaVuFont],
  );
  final cellStyleRed = pw.TextStyle(
    font: notoFont,
    fontSize: 10,
    color: PdfColor.fromInt(0xffe53935),
    fontFallback: [dejaVuFont],
  );
  final cellStyleBold = pw.TextStyle(
    font: montserratBold,
    fontSize: 10,
    color: PdfColor.fromInt(0xff000000),
    fontFallback: [dejaVuFont],
  );

  // Table header
  final header = pw.TableRow(
    decoration: pw.BoxDecoration(color: green),
    children: [
      pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.all(6),
        child: pw.Text('TEAM', style: headerStyle),
      ),
      pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.all(6),
        child: pw.Text('COMPETENCY', style: headerStyle),
      ),
      pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.all(6),
        child: pw.Text('TYPE OF TEAM', style: headerStyle),
      ),
      pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.all(6),
        child: pw.Text('PPE', style: headerStyle),
      ),
    ],
  );

  // Table rows
  List<pw.TableRow> rows = [];
  for (final team in summaryTeams) {
    // COMPETENCY: tick or red X
    final competency = (team['competency'] ?? '').toString().trim();
    final isNotCompetent = competency.toLowerCase().contains('not') &&
        competency.toLowerCase().contains('competent');
    final competencyWidget = isNotCompetent
        ? pw.Text('X', style: cellStyleRed)
        : pw.Text('✓', style: cellStyle);

    // TYPE OF TEAM: bold red if flagged or contains 'NOT'
    final typeOfTeam = (team['typeOfTeam'] ?? '').toString();
    final typeOfTeamRedFlag = (team['typeOfTeamRed'] ?? 0) == 1;
    final typeOfTeamWidget =
        (typeOfTeamRedFlag || typeOfTeam.toUpperCase().contains('NOT'))
            ? pw.Text(typeOfTeam, style: cellStyleRed)
            : pw.Text(typeOfTeam, style: cellStyleBold);

    // PPE: bold red if flagged
    final ppe = (team['ppe'] ?? '').toString();
    final ppeRedFlag = (team['ppeRed'] ?? 0) == 1;
    final ppeWidget = ppeRedFlag
        ? pw.Text(ppe, style: cellStyleRed)
        : pw.Text(ppe, style: cellStyle);

    // Use team label instead of teamId
    final teamId = team['teamId'] ?? '';
    final teamLabel = teamIdToLabel[teamId] ?? teamId.toString();

    rows.add(
      pw.TableRow(
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.all(4),
            child: pw.Text(teamLabel, style: cellStyle), // show label
          ),
          pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.all(4),
            child: competencyWidget,
          ),
          pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.all(4),
            child: typeOfTeamWidget,
          ),
          pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.all(4),
            child: ppeWidget,
          ),
        ],
      ),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 16), // <-- Add this line for top spacing
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY BY TEAM $teamType – $companyName',
            style: pw.TextStyle(
              font: montserratBold,
              fontSize: 16,
              color: PdfColor.fromInt(0xff000000),
            ),
          ),
          pw.Spacer(),
          pw.Image(pw.MemoryImage(tmLogoBytes), width: 80),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: borderColor, width: 1),
        columnWidths: {
          0: pw.FlexColumnWidth(2), // TEAM
          1: pw.FlexColumnWidth(2), // COMPETENCY
          2: pw.FlexColumnWidth(5), // TYPE OF TEAM
          3: pw.FlexColumnWidth(5), // PPE
        },
        children: [header, ...rows],
      ),
      pw.Spacer(),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(pageNumber.toString(),
              style: pw.TextStyle(font: notoFont, fontSize: 12)),
        ],
      ),
    ],
  );
}

// Helper to build a team card as in the attached image
pw.Widget buildTeamCard(
    Map<String, dynamic> team,
    Uint8List? imageBytes,
    List<String> memberNames,
    String remark,
    Uint8List appIconBytes,
    pw.Font notoFont,
    pw.Font montserratBold,
    {double borderWidth = 1.5}) {
  final blue = PdfColor.fromInt(0xff0033cc);
  final lightBlue = PdfColor.fromInt(0xffe3eefe);

  return pw.Stack(
    alignment: pw.Alignment.topCenter,
    children: [
      // Card with content
      pw.Container(
        margin: pw.EdgeInsets.only(
            top: 120), // push card further down for image overlap
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: lightBlue, width: borderWidth),
          color: PdfColors.white,
        ),
        child: pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(18, 60, 18, 18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  (team['label'] ?? '').toString().toUpperCase(),
                  style: pw.TextStyle(
                      font: montserratBold, fontSize: 18, color: blue),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 12), // smaller gap
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(pw.MemoryImage(appIconBytes),
                      width: 24, height: 24), // smaller icon
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'From Left',
                          style: pw.TextStyle(
                            font: montserratBold,
                            fontSize: 10, // smaller
                            color: blue,
                          ),
                        ),
                        // Display each member name on its own line, allow up to 2 lines per name
                        ...memberNames
                            .where((n) => n.trim().isNotEmpty)
                            .map((n) => pw.Container(
                                  margin: pw.EdgeInsets.only(bottom: 2),
                                  child: pw.Text(
                                    n,
                                    style: pw.TextStyle(
                                      font: notoFont,
                                      fontSize: 9, // smaller
                                      color: PdfColor.fromInt(0xff000000),
                                    ),
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                )),
                        if (remark.isNotEmpty) ...[
                          pw.SizedBox(height: 10), // smaller gap
                          pw.Text(
                            'REMARK:',
                            style: pw.TextStyle(
                              font: montserratBold,
                              fontSize: 10, // smaller
                              color: blue,
                            ),
                          ),
                          pw.Text(
                            remark,
                            style: pw.TextStyle(
                              font: notoFont,
                              fontSize: 9, // smaller
                              color: PdfColor.fromInt(0xffe53935),
                            ),
                            maxLines: 6,
                            softWrap: true,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // Image: sits on top, full height
      pw.Positioned(
        top: 0,
        child: (imageBytes != null)
            ? pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.white, width: 4),
                ),
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  width: 170,
                  height: 170,
                  fit: pw.BoxFit.contain,
                ),
              )
            : pw.Container(
                width: 170,
                height: 170,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  border: pw.Border.all(color: PdfColors.white, width: 4),
                ),
                alignment: pw.Alignment.center,
                // No app icon, just empty grey
              ),
      ),
    ],
  );
}

// Utility: Check if a string contains the keyword 'NOT' (case-insensitive)
bool containsNotKeyword(String value) {
  return value.toUpperCase().contains('NOT');
}

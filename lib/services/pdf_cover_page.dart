/* import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/document.dart';

pw.Page buildCoverPage(Document doc, String dateStr, dynamic coverImage,
    dynamic tmLogo, pw.Font notoFont, pw.Font montserratBold) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: pw.EdgeInsets.zero,
    build: (pw.Context context) {
      return pw.Row(
        children: [
          pw.Container(
            width: PdfPageFormat.a4.landscape.width * 0.5,
            height: PdfPageFormat.a4.landscape.height,
            child: pw.Image(coverImage, fit: pw.BoxFit.cover),
          ),
          pw.Container(
            width: PdfPageFormat.a4.landscape.width * 0.5,
            height: PdfPageFormat.a4.landscape.height,
            padding: pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: pw.Stack(
              children: [
                pw.Positioned(
                  top: 0,
                  right: 0,
                  child: pw.Image(tmLogo, width: 90),
                ),
                pw.Positioned(
                  left: 0,
                  top: 60,
                  right: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CM TEAM COMPLIANCE',
                        style: pw.TextStyle(
                          fontSize: 36,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xff0033cc),
                          font: montserratBold,
                        ),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Text('Date: $dateStr',
                          style: pw.TextStyle(
                            fontSize: 20,
                            color: PdfColor.fromInt(0xff0033cc),
                            font: notoFont,
                          )),
                      pw.Text('Audit ${doc.description}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            color: PdfColor.fromInt(0xff0033cc),
                            font: notoFont,
                          )),
                      pw.Text('Location: ${doc.location}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            color: PdfColor.fromInt(0xff0033cc),
                            font: notoFont,
                          )),
                      pw.Text('Auditor: ${doc.auditor}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            color: PdfColor.fromInt(0xff0033cc),
                            font: notoFont,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
} */

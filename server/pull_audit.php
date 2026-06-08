<?php
/**
 * pull_audit.php — V-Audit API
 * Dynamically queries all related relational tables and reconstructs 
 * the exact nested JSON structure expected by the Flutter Offline-First app.
 */

declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');

$dbHost = '127.0.0.1';
$dbName = 'v_audit';
$dbUser = 'root';
$dbPass = '';

try {
    $pdo = new PDO("mysql:host={$dbHost};dbname={$dbName};charset=utf8mb4", $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);

    // 1. Fetch all documents
    $stmtDocs = $pdo->query("SELECT * FROM documents");
    $documents = $stmtDocs->fetchAll();

    $response = [];

    foreach ($documents as $doc) {
        $docId = $doc['id'];
        
        // 2. Fetch Teams for this document
        $stmtTeams = $pdo->prepare("SELECT * FROM teams WHERE documentId = ?");
        $stmtTeams->execute([$docId]);
        $teams = $stmtTeams->fetchAll();
        
        // 3. Fetch Profiling for this document
        $stmtProf = $pdo->prepare("SELECT * FROM profiling_team WHERE documentId = ?");
        $stmtProf->execute([$docId]);
        $profiling = $stmtProf->fetchAll();
        
        // 4. Fetch Summary Team for this document (joined via teams)
        $stmtSumm = $pdo->prepare("
            SELECT st.* 
            FROM summary_team st 
            JOIN teams t ON st.teamId = t.id 
            WHERE t.documentId = ?
        ");
        $stmtSumm->execute([$docId]);
        $summary = $stmtSumm->fetchAll();
        
        // 5. Fetch Company Name (Evidence) for this document (joined via teams)
        $stmtComp = $pdo->prepare("
            SELECT cn.* 
            FROM company_name cn 
            JOIN teams t ON cn.teamId = t.id 
            WHERE t.documentId = ?
        ");
        $stmtComp->execute([$docId]);
        $companyName = $stmtComp->fetchAll();
        
        // 6. Fetch Finding Summary for this document
        $stmtFind = $pdo->prepare("SELECT * FROM finding_summary WHERE documentId = ?");
        $stmtFind->execute([$docId]);
        $finding = $stmtFind->fetchAll();

        // Standardize datatypes for SQLite ingestion in Dart
        $doc['isDraft'] = isset($doc['isDraft']) ? (int)$doc['isDraft'] : 1;
        
        foreach ($summary as &$s) {
            $s['typeOfTeamRed'] = isset($s['typeOfTeamRed']) ? (int)$s['typeOfTeamRed'] : 0;
            $s['ppeRed'] = isset($s['ppeRed']) ? (int)$s['ppeRed'] : 0;
        }

        foreach ($companyName as &$cn) {
            $cn['latitude'] = isset($cn['latitude']) ? (float)$cn['latitude'] : null;
            $cn['longitude'] = isset($cn['longitude']) ? (float)$cn['longitude'] : null;
            $cn['altitude'] = isset($cn['altitude']) ? (float)$cn['altitude'] : null;
        }

        foreach ($teams as &$t) {
            $t['number'] = isset($t['number']) ? (int)$t['number'] : null;
        }

        foreach ($profiling as &$p) {
            $p['personIndex'] = isset($p['personIndex']) ? (int)$p['personIndex'] : null;
        }
        
        // Reconstruct exact nested Map for Dart `importRawAuditData`
        $payload = [
            'document' => $doc,
            'teams' => $teams,
            'profilingData' => $profiling,
            'summaryData' => $summary,
            'companyNameData' => $companyName,
            'findingData' => $finding,
        ];
        
        $response[] = $payload;
    }

    echo json_encode(['ok' => true, 'data' => $response], JSON_UNESCAPED_SLASHES);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}
?>

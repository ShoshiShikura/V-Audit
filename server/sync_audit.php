<?php
/**
 * sync_audit.php — V-Audit API
 * Robust JSON parsing endpoint to handle UPSERT logic (Insert or Update) for offline syncing.
 * It strictly syncs elements linked to Audit Tracking natively inside XAMPP.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

function respond(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
    exit;
}

// Ensure POST request
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(['ok' => false, 'message' => 'Invalid request method. Use POST.'], 405);
}

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    respond(['ok' => false, 'message' => 'Invalid or missing JSON payload'], 400);
}

// DB config
$dbHost = '127.0.0.1';
$dbName = 'v_audit';
$dbUser = 'root';
$dbPass = '';

try {
    $pdo = new PDO(
        "mysql:host={$dbHost};dbname={$dbName};charset=utf8mb4",
        $dbUser,
        $dbPass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $pdo->beginTransaction();

    try {
        // 1. Sync Documents
        if (isset($input['documents']) && is_array($input['documents'])) {
            $stmt = $pdo->prepare("
                INSERT INTO documents (id, title, description, type, createdDate, lastModified, fileName, isDraft, ownerId, location, auditor) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                title=VALUES(title), description=VALUES(description), type=VALUES(type), lastModified=VALUES(lastModified), fileName=VALUES(fileName), isDraft=VALUES(isDraft), ownerId=VALUES(ownerId), location=VALUES(location), auditor=VALUES(auditor)
            ");
            foreach ($input['documents'] as $doc) {
                $stmt->execute([
                    $doc['id'] ?? null,
                    $doc['title'] ?? null,
                    $doc['description'] ?? null,
                    $doc['type'] ?? null,
                    $doc['createdDate'] ?? null,
                    $doc['lastModified'] ?? null,
                    $doc['fileName'] ?? null,
                    isset($doc['isDraft']) ? (int)$doc['isDraft'] : 1,
                    $doc['ownerId'] ?? null,
                    $doc['location'] ?? null,
                    $doc['auditor'] ?? null
                ]);
            }
        }

        // 2. Sync Audit Templates
        if (isset($input['audit_templates']) && is_array($input['audit_templates'])) {
            $stmt = $pdo->prepare("
                INSERT INTO audit_templates (id, name, description, isPublished, createdDate, lastModified) 
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                name=VALUES(name), description=VALUES(description), isPublished=VALUES(isPublished), lastModified=VALUES(lastModified)
            ");
            foreach ($input['audit_templates'] as $tpl) {
                $stmt->execute([
                    $tpl['id'] ?? null,
                    $tpl['name'] ?? null,
                    $tpl['description'] ?? null,
                    isset($tpl['isPublished']) ? (int)$tpl['isPublished'] : 0,
                    $tpl['createdDate'] ?? null,
                    $tpl['lastModified'] ?? null
                ]);
            }
        }

        // 3. Sync Teams
        if (isset($input['teams']) && is_array($input['teams'])) {
            $stmt = $pdo->prepare("
                INSERT INTO teams (id, documentId, type, label, number) 
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                type=VALUES(type), label=VALUES(label), number=VALUES(number)
            ");
            foreach ($input['teams'] as $team) {
                $stmt->execute([
                    $team['id'] ?? null,
                    $team['documentId'] ?? null,
                    $team['type'] ?? null,
                    $team['label'] ?? null,
                    $team['number'] ?? null
                ]);
            }
        }

        // 4. Sync Profiling Team
        if (isset($input['profiling_team']) && is_array($input['profiling_team'])) {
            $stmt = $pdo->prepare("
                INSERT INTO profiling_team (id, documentId, teamId, personIndex, name, ic, attendance, ntsmpDate, aespDate, agtesDate, csmeDate, oykDate, poleProficiency, ca2aDate, ca2cDate) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                name=VALUES(name), ic=VALUES(ic), attendance=VALUES(attendance), ntsmpDate=VALUES(ntsmpDate), aespDate=VALUES(aespDate), agtesDate=VALUES(agtesDate), csmeDate=VALUES(csmeDate), oykDate=VALUES(oykDate), poleProficiency=VALUES(poleProficiency), ca2aDate=VALUES(ca2aDate), ca2cDate=VALUES(ca2cDate)
            ");
            foreach ($input['profiling_team'] as $pt) {
                $stmt->execute([
                    $pt['id'] ?? null,
                    $pt['documentId'] ?? null,
                    $pt['teamId'] ?? null,
                    $pt['personIndex'] ?? null,
                    $pt['name'] ?? null,
                    $pt['ic'] ?? null,
                    $pt['attendance'] ?? null,
                    $pt['ntsmpDate'] ?? null,
                    $pt['aespDate'] ?? null,
                    $pt['agtesDate'] ?? null,
                    $pt['csmeDate'] ?? null,
                    $pt['oykDate'] ?? null,
                    $pt['poleProficiency'] ?? null,
                    $pt['ca2aDate'] ?? null,
                    $pt['ca2cDate'] ?? null
                ]);
            }
        }

        // 5. Sync Finding Summary
        if (isset($input['finding_summary']) && is_array($input['finding_summary'])) {
            $stmt = $pdo->prepare("
                INSERT INTO finding_summary (documentId, remark) 
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE 
                remark=VALUES(remark)
            ");
            foreach ($input['finding_summary'] as $fs) {
                $stmt->execute([
                    $fs['documentId'] ?? null,
                    $fs['remark'] ?? null
                ]);
            }
        }

        // 4. Sync Summary Team
        if (isset($input['summary_team']) && is_array($input['summary_team'])) {
            $stmt = $pdo->prepare("
                INSERT INTO summary_team (teamId, typeOfTeam, ppe, competency, typeOfTeamRed, ppeRed) 
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                typeOfTeam=VALUES(typeOfTeam), ppe=VALUES(ppe), competency=VALUES(competency), typeOfTeamRed=VALUES(typeOfTeamRed), ppeRed=VALUES(ppeRed)
            ");
            foreach ($input['summary_team'] as $st) {
                $stmt->execute([
                    $st['teamId'] ?? null,
                    $st['typeOfTeam'] ?? null,
                    $st['ppe'] ?? null,
                    $st['competency'] ?? null,
                    isset($st['typeOfTeamRed']) ? (int)$st['typeOfTeamRed'] : 0,
                    isset($st['ppeRed']) ? (int)$st['ppeRed'] : 0
                ]);
            }
        }

        // 5. Sync Company Name (Evidence mappings)
        if (isset($input['company_name']) && is_array($input['company_name'])) {
            $stmt = $pdo->prepare("
                INSERT INTO company_name (teamId, attachmentPath, capturedAt, latitude, longitude, altitude, remark, members) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                attachmentPath=VALUES(attachmentPath), capturedAt=VALUES(capturedAt), latitude=VALUES(latitude), longitude=VALUES(longitude), altitude=VALUES(altitude), remark=VALUES(remark), members=VALUES(members)
            ");
            foreach ($input['company_name'] as $cn) {
                // Ensure double conversion for GPS elements
                $lat = isset($cn['latitude']) && $cn['latitude'] !== '' ? (float)$cn['latitude'] : null;
                $lng = isset($cn['longitude']) && $cn['longitude'] !== '' ? (float)$cn['longitude'] : null;
                $alt = isset($cn['altitude']) && $cn['altitude'] !== '' ? (float)$cn['altitude'] : null;

                $stmt->execute([
                    $cn['teamId'] ?? null,
                    $cn['attachmentPath'] ?? null,
                    $cn['capturedAt'] ?? null,
                    $lat,
                    $lng,
                    $alt,
                    $cn['remark'] ?? null,
                    $cn['members'] ?? null
                ]);
            }
        }

        // 6. Sync Companies
        if (isset($input['companies']) && is_array($input['companies'])) {
            $stmt = $pdo->prepare("
                INSERT INTO companies (id, name) 
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE 
                name=VALUES(name)
            ");
            foreach ($input['companies'] as $comp) {
                $stmt->execute([
                    $comp['id'] ?? null,
                    $comp['name'] ?? null
                ]);
            }
        }

        $pdo->commit();
        respond(['ok' => true, 'message' => 'Sync operation completed effectively with UPSERT mechanisms protecting legacy records.']);

    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }

} catch (Throwable $e) {
    respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

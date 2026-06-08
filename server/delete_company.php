<?php
/**
 * delete_company.php
 * Endpoint to safely delete a company from XAMPP database.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

function respond(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(['ok' => false, 'message' => 'Invalid request method.'], 405);
}

$companyName = $_POST['name'] ?? '';

if (empty($companyName)) {
    respond(['ok' => false, 'message' => 'Missing company name.'], 400);
}

$dbHost = '127.0.0.1';
$dbName = 'v_audit';
$dbUser = 'root';
$dbPass = '';

try {
    $pdo = new PDO(
        "mysql:host={$dbHost};dbname={$dbName};charset=utf8mb4",
        $dbUser,
        $dbPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $stmt = $pdo->prepare("DELETE FROM companies WHERE name = ?");
    $stmt->execute([$companyName]);

    respond(['ok' => true, 'message' => 'Company deleted successfully.']);
} catch (Exception $e) {
    respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

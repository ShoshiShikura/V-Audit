<?php
/**
 * add_worker.php — V-Audit API
 * Adds a new worker to the MySQL database.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

function respond(array $data, int $status = 200): void {
  http_response_code($status);
  echo json_encode($data, JSON_UNESCAPED_SLASHES);
  exit;
}

// DB config
$dbHost = '127.0.0.1';
$dbName = 'v_audit';
$dbUser = 'root';
$dbPass = '';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(['ok' => false, 'message' => 'Invalid request method. Use POST.'], 405);
}

// Read JSON input
$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    respond(['ok' => false, 'message' => 'Invalid or missing JSON payload'], 400);
}

$userId = $input['userId'] ?? '';
$name = $input['name'] ?? '';
$ic = $input['ic'] ?? '';
$companies = $input['companies'] ?? ''; // Expecting a comma-separated string
$status = $input['status'] ?? 'active';

if (empty($userId) || empty($name)) {
    respond(['ok' => false, 'message' => 'userId and name are required'], 400);
}

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

  $stmt = $pdo->prepare("INSERT INTO workers (userId, name, ic, companies, status) VALUES (?, ?, ?, ?, ?)");
  $success = $stmt->execute([$userId, $name, $ic, $companies, $status]);

  if ($success) {
      respond(['ok' => true, 'message' => 'Worker added successfully']);
  } else {
      respond(['ok' => false, 'message' => 'Failed to add worker'], 500);
  }
} catch (PDOException $e) {
  // Handle duplicate key error gracefully
  if ($e->errorInfo[1] == 1062) {
      respond(['ok' => false, 'message' => 'Worker with this userId already exists'], 409);
  }
  respond(['ok' => false, 'message' => 'Database error: ' . $e->getMessage()], 500);
} catch (Throwable $e) {
  respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

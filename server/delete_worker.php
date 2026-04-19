<?php
/**
 * delete_worker.php — V-Audit API
 * Deletes a worker from the MySQL database by userId.
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    respond(['ok' => false, 'message' => 'Invalid request method. Use POST or DELETE.'], 405);
}

// Support both URL parameters and JSON body
$userId = $_GET['userId'] ?? null;

if (!$userId) {
    $input = json_decode(file_get_contents('php://input'), true);
    if ($input && isset($input['userId'])) {
        $userId = $input['userId'];
    }
}

if (empty($userId)) {
    respond(['ok' => false, 'message' => 'userId is required'], 400);
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

  $stmt = $pdo->prepare("DELETE FROM workers WHERE userId = ?");
  $stmt->execute([$userId]);

  if ($stmt->rowCount() > 0) {
      respond(['ok' => true, 'message' => 'Worker deleted successfully']);
  } else {
      // Row didn't exist or wasn't deleted
      respond(['ok' => true, 'message' => 'Worker not found or already deleted']);
  }
} catch (Throwable $e) {
  respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

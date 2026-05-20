<?php
/**
 * delete_user.php — V-Audit API
 * Deletes a user from the MySQL database by their ID.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

function respond(array $data, int $status = 200): void {
  http_response_code($status);
  echo json_encode($data, JSON_UNESCAPED_SLASHES);
  exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  respond(['ok' => false, 'message' => 'POST required'], 405);
}

$id = trim($_POST['id'] ?? '');
if ($id === '') {
  respond(['ok' => false, 'message' => 'Missing user id'], 400);
}

// DB config (must match login.php / list_users.php)
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

  $stmt = $pdo->prepare("DELETE FROM users WHERE id = :id");
  $stmt->execute(['id' => $id]);

  if ($stmt->rowCount() > 0) {
    respond(['ok' => true, 'message' => "User '$id' deleted."]);
  } else {
    respond(['ok' => true, 'message' => "User '$id' not found on server (already deleted)."]);
  }
} catch (Throwable $e) {
  respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

<?php
/**
 * list_users.php — V-Audit API
 * Returns all registered users from the MySQL database.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

function respond(array $data, int $status = 200): void {
  http_response_code($status);
  echo json_encode($data, JSON_UNESCAPED_SLASHES);
  exit;
}

// DB config (must match login.php)
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

  $stmt = $pdo->query("SELECT id, role, fullName FROM users");
  $users = $stmt->fetchAll();

  respond([
    'ok' => true,
    'users' => $users,
  ]);
} catch (Throwable $e) {
  respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

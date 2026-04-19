<?php
/**
 * list_workers.php — V-Audit API
 * Returns all registered workers from the MySQL database.
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

  $stmt = $pdo->query("SELECT userId, name, ic, companies, status FROM workers ORDER BY name ASC");
  $workers = $stmt->fetchAll();

  respond([
    'ok' => true,
    'workers' => $workers,
  ]);
} catch (Throwable $e) {
  respond(['ok' => false, 'message' => 'Server error: ' . $e->getMessage()], 500);
}

<?php
/**
 * list_users.php — V-Audit API
 * Returns all registered users from the MySQL database.
 * Place this file alongside login.php in your XAMPP htdocs/vaudit_api/ folder.
 */

header('Content-Type: application/json');

$host = 'localhost';
$db   = 'vaudit';
$user = 'root';
$pass = '';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $stmt = $pdo->query("SELECT id, role, fullName FROM users");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'ok' => true,
        'users' => $users,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'message' => 'Database error: ' . $e->getMessage(),
    ]);
}

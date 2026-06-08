<?php
/**
 * upsert_user.php — V-Audit API
 * Inserts or updates a user in the MySQL database.
 */

declare(strict_types=1);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
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
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    // Can receive data as JSON or form data
    $data = json_decode(file_get_contents("php://input"), true);
    if (!$data) {
        $data = $_POST;
    }

    if (!isset($data['id']) || !isset($data['password']) || !isset($data['role'])) {
        echo json_encode(["ok" => false, "message" => "Missing required fields"]);
        exit();
    }

    $id = $data['id'];
    $password = $data['password'];
    $role = $data['role'];
    $fullName = $data['fullName'] ?? '';

    // Insert or update
    $stmt = $pdo->prepare("
        INSERT INTO users (id, password, role, fullName, activated, password_reset_requested) 
        VALUES (:id, :password, :role, :fullName, 1, 0)
        ON DUPLICATE KEY UPDATE 
            password = VALUES(password), 
            role = VALUES(role), 
            fullName = VALUES(fullName),
            password_reset_requested = 0
    ");
    
    $stmt->execute([
        ':id' => $id,
        ':password' => $password,
        ':role' => $role,
        ':fullName' => $fullName
    ]);

    echo json_encode(["ok" => true, "message" => "User upserted successfully"]);

} catch (Throwable $e) {
    echo json_encode(["ok" => false, "message" => "Server error: " . $e->getMessage()]);
}
?>

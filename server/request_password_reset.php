<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$host = 'localhost';
$db   = 'vaudit_db'; // Adjust if db name is different
$user = 'root';
$pass = '';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (\PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database connection failed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"));
if (!isset($data->username)) {
    echo json_encode(["status" => "error", "message" => "Username not provided"]);
    exit();
}

$username = $data->username;

try {
    $stmt = $pdo->prepare("UPDATE users SET password_reset_requested = 1 WHERE id = ?");
    $stmt->execute([$username]);

    if ($stmt->rowCount() > 0) {
        echo json_encode(["status" => "success", "message" => "Password reset requested"]);
    } else {
        echo json_encode(["status" => "error", "message" => "User not found or already requested"]);
    }
} catch (\PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Error updating record: " . $e->getMessage()]);
}
?>

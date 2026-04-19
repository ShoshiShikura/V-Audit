<?php
/**
 * upload_evidence.php — V-Audit API
 * Receives multipart/form-data to securely parse and save stamped images (evidence).
 * Automatically maps to the 'uploads/' folder.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

function respond(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(['ok' => false, 'message' => 'Invalid request method. Use POST.'], 405);
}

// 1. Ensure the uploads directory exists
$uploadDir = __DIR__ . '/uploads';
if (!is_dir($uploadDir)) {
    if (!mkdir($uploadDir, 0777, true) && !is_dir($uploadDir)) {
        respond(['ok' => false, 'message' => 'Failed to automatically create the uploads staging directory.'], 500);
    }
}

// 2. Validate incoming file
if (!isset($_FILES['evidence_image']) || $_FILES['evidence_image']['error'] !== UPLOAD_ERR_OK) {
    respond(['ok' => false, 'message' => 'No image uploaded successfully or a transmission error occurred.'], 400);
}

// 3. Process the file
$fileTmpPath = $_FILES['evidence_image']['tmp_name'];
$fileName = $_FILES['evidence_image']['name'];
$fileSize = $_FILES['evidence_image']['size'];

// Optional: Validate file type / size (e.g., max 5MB as per the Dart codebase)
if ($fileSize > 5 * 1024 * 1024) {
    respond(['ok' => false, 'message' => 'File size exceeds limit (5MB).'], 400);
}

// Ensure unique naming locally without destroying the extension
$fileNameCmps = explode(".", $fileName);
$fileExtension = strtolower(end($fileNameCmps));
$allowedfileExtensions = ['jpg', 'gif', 'png', 'jpeg'];

if (!in_array($fileExtension, $allowedfileExtensions)) {
    respond(['ok' => false, 'message' => 'Upload failed. Allowed file types: ' . implode(',', $allowedfileExtensions)], 400);
}

$newFileName = md5(time() . $fileName) . '.' . $fileExtension;
$destPath = $uploadDir . '/' . $newFileName;

if(move_uploaded_file($fileTmpPath, $destPath)) {
    // Return relative path simulating how the internal server structures paths
    $relativePath = 'uploads/' . $newFileName;
    respond(['ok' => true, 'message' => 'Evidence Image uploaded securely.', 'path' => $relativePath]);
} else {
    respond(['ok' => false, 'message' => 'There was an error moving the uploaded file to the designated directory.'], 500);
}

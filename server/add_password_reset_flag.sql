-- Add password_reset_requested column to users table
ALTER TABLE users ADD COLUMN password_reset_requested TINYINT(1) DEFAULT 0;

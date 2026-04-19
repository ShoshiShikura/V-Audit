-- V-Audit Database System
-- Schema matching the Flutter `DatabaseHelper` local database for full compatibility.

-- 1. Create audit_templates Table (Corresponds to Audit_Template in legacy Data Dictionary)
CREATE TABLE IF NOT EXISTS audit_templates (
  id VARCHAR(100) PRIMARY KEY,       -- Secure UUID matching local SQLite
  name VARCHAR(255) NOT NULL,        -- Replaces title
  description TEXT,                  -- Replaces category/description
  isPublished TINYINT(1) DEFAULT 0,
  createdDate DATETIME,
  lastModified DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Create documents Table (Corresponds to Audit_Record in legacy Data Dictionary)
CREATE TABLE IF NOT EXISTS documents (
  id VARCHAR(100) PRIMARY KEY,       -- Secure UUID matching local SQLite
  title VARCHAR(255),                
  description TEXT,                  -- Often used to save "siteName" or company name
  type VARCHAR(50),
  createdDate DATETIME,
  lastModified DATETIME,
  fileName VARCHAR(255),
  isDraft TINYINT(1) DEFAULT 1,      -- Boolean indicating Draft (1) or Exported (0)
  ownerId VARCHAR(100),              -- Owner or Creator ID
  location TEXT,                     -- Captures gpsStart logic
  auditor VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

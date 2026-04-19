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
  location TEXT,                     -- Captures general location logic
  auditor VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Create finding_summary & summary_team Tables (Corresponds to Finding in legacy Data Dictionary)
-- Your legacy dictionary utilized a checklist methodology, but the app has streamlined 
-- Findings into general audit remarks and component performance indicators.

CREATE TABLE IF NOT EXISTS finding_summary (
  documentId VARCHAR(100) PRIMARY KEY,  -- Linked directly to your Audit Record ID
  remark TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS summary_team (
  teamId VARCHAR(100) PRIMARY KEY,      
  typeOfTeam VARCHAR(50),
  ppe VARCHAR(50),                      -- Tracks checklist compliance points practically
  competency VARCHAR(50),
  typeOfTeamRed TINYINT(1) DEFAULT 0,
  ppeRed TINYINT(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Create company_name Table (Corresponds to Evidence in legacy Data Dictionary)
-- This table natively functions as your Evidence table locally, linking attachment pathways 
-- alongside exact GPS capture elements mirroring your initial expectations.

CREATE TABLE IF NOT EXISTS company_name (
  teamId VARCHAR(100) PRIMARY KEY,
  attachmentPath VARCHAR(255) DEFAULT NULL,  -- Replaces imagePath
  capturedAt DATETIME DEFAULT NULL,          -- Replaces timestamp
  latitude DOUBLE DEFAULT NULL,
  longitude DOUBLE DEFAULT NULL,
  altitude DOUBLE DEFAULT NULL,
  remark TEXT,
  members TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- This script will completely wipe all audit document data from the server.
-- It will NOT delete your users, templates, or companies.

TRUNCATE TABLE `finding_summary`;
TRUNCATE TABLE `company_name`;
TRUNCATE TABLE `summary_team`;
TRUNCATE TABLE `profiling_team`;
TRUNCATE TABLE `teams`;
TRUNCATE TABLE `documents`;

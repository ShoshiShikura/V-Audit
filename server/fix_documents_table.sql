ALTER TABLE `documents` ADD COLUMN `templateId` TEXT DEFAULT 'default_vmm_template';
ALTER TABLE `documents` ADD COLUMN `status` TEXT DEFAULT 'draft';
ALTER TABLE `documents` ADD COLUMN `rejectionRemark` TEXT DEFAULT '';
ALTER TABLE `documents` ADD COLUMN `isRead` INTEGER DEFAULT 0;

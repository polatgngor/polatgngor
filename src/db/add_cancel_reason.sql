ALTER TABLE `rides`
ADD COLUMN `cancel_reason` VARCHAR(255) NULL AFTER `status`;

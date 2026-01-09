ALTER TABLE `drivers`
ADD COLUMN `working_region` ENUM('Anadolu', 'Avrupa') NULL AFTER `vehicle_license_file`,
ADD COLUMN `working_district` VARCHAR(100) NULL AFTER `working_region`;

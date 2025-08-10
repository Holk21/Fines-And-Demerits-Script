-- qb-fines-demerits SQL (v1.2.1)

-- Stores each fine (paid or unpaid) with amounts and points applied at issue time
CREATE TABLE IF NOT EXISTS `player_fines` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `officer_id` VARCHAR(50) NOT NULL,
  `officer_name` VARCHAR(100) NOT NULL,
  `target_id` VARCHAR(50) NOT NULL,
  `target_name` VARCHAR(100) NOT NULL,
  `target_cid` VARCHAR(50) NOT NULL,
  `offence_code` VARCHAR(50) NOT NULL,
  `offence_label` VARCHAR(255) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `demerit_points` INT NOT NULL DEFAULT 0,
  `payment_method` VARCHAR(10) NOT NULL DEFAULT 'unpaid',
  `note` VARCHAR(255) NULL,
  `paid` TINYINT(1) NOT NULL DEFAULT 0,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `targetcid_idx` (`target_cid`),
  KEY `paid_idx` (`paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tracks demerit history entries (source of truth for rolling 24-month calc)
CREATE TABLE IF NOT EXISTS `player_demerits` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `points` INT NOT NULL DEFAULT 0,
  `offence_code` VARCHAR(50) NOT NULL,
  `offence_label` VARCHAR(255) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `cid_idx` (`citizenid`),
  KEY `created_idx` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional record of suspension events for auditing
CREATE TABLE IF NOT EXISTS `player_suspensions` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `start_date` DATE NOT NULL,
  `months` INT NOT NULL DEFAULT 3,
  `reason` VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

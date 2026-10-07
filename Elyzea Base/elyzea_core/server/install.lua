--[[
    ELYZEA CORE — création automatique des tables (compatibles avec une ancienne base Qbox :
    les personnages, l'argent, les métiers et les véhicules existants sont conservés).
]]

local TABLES = {
[[CREATE TABLE IF NOT EXISTS `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `cid` int(11) DEFAULT NULL,
  `license` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `money` text NOT NULL,
  `charinfo` text DEFAULT NULL,
  `job` text NOT NULL,
  `gang` text DEFAULT NULL,
  `position` text NOT NULL,
  `metadata` text NOT NULL,
  `inventory` longtext DEFAULT NULL,
  `phone_number` varchar(20) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_logged_out` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `id` (`id`),
  KEY `last_updated` (`last_updated`),
  KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

[[CREATE TABLE IF NOT EXISTS `player_groups` (
  `citizenid` varchar(50) NOT NULL,
  `group` varchar(50) NOT NULL,
  `type` varchar(50) NOT NULL,
  `grade` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`citizenid`, `type`, `group`),
  CONSTRAINT `fk_ely_groups_citizenid` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

[[CREATE TABLE IF NOT EXISTS `player_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL,
  `hash` varchar(50) DEFAULT NULL,
  `mods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `plate` varchar(15) NOT NULL,
  `fakeplate` varchar(50) DEFAULT NULL,
  `garage` varchar(50) DEFAULT NULL,
  `fuel` int(11) DEFAULT 100,
  `engine` float DEFAULT 1000,
  `body` float DEFAULT 1000,
  `state` int(11) DEFAULT 1,
  `depotprice` int(11) NOT NULL DEFAULT 0,
  `drivingdistance` int(50) DEFAULT NULL,
  `status` text DEFAULT NULL,
  `coords` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `plate` (`plate`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

[[CREATE TABLE IF NOT EXISTS `elyzea_society` (
  `name` varchar(60) NOT NULL,
  `balance` bigint(20) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

[[CREATE TABLE IF NOT EXISTS `elyzea_society_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `society` varchar(60) NOT NULL,
  `amount` bigint(20) NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `society` (`society`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

[[CREATE TABLE IF NOT EXISTS `elyzea_bank_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `label` varchar(255) NOT NULL,
  `amount` bigint(20) NOT NULL,
  `balance` bigint(20) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

DatabaseReady = false

CreateThread(function()
    MySQL.ready.await()
    for _, sql in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print(('^1[elyzea_core] Création de table impossible : %s^0'):format(tostring(err))) end
    end
    -- Anciennes bases : colonne ajoutée par les versions récentes
    pcall(MySQL.query.await, 'ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `last_logged_out` timestamp NULL DEFAULT NULL')
    DatabaseReady = true
    TriggerEvent('elyzea:server:databaseReady')
end)

function AwaitDatabase()
    while not DatabaseReady do Wait(100) end
end

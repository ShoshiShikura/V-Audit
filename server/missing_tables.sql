CREATE TABLE `teams` (
  `id` varchar(100) NOT NULL PRIMARY KEY,
  `documentId` varchar(100) NOT NULL,
  `type` varchar(100) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `number` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `profiling_team` (
  `id` varchar(100) NOT NULL PRIMARY KEY,
  `documentId` varchar(100) NOT NULL,
  `teamId` varchar(100) NOT NULL,
  `personIndex` int(11) DEFAULT NULL,
  `name` TEXT DEFAULT NULL,
  `ic` TEXT DEFAULT NULL,
  `attendance` varchar(100) DEFAULT NULL,
  `ntsmpDate` varchar(50) DEFAULT NULL,
  `aespDate` varchar(50) DEFAULT NULL,
  `agtesDate` varchar(50) DEFAULT NULL,
  `csmeDate` varchar(50) DEFAULT NULL,
  `oykDate` varchar(50) DEFAULT NULL,
  `poleProficiency` varchar(50) DEFAULT NULL,
  `ca2aDate` varchar(50) DEFAULT NULL,
  `ca2cDate` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `store_items` ADD `flags` varchar(11) DEFAULT NULL;
ALTER TABLE `store_items` ADD COLUMN `priority` INT(11) NOT NULL DEFAULT '0' AFTER `id`;
ALTER TABLE `store_items` ADD COLUMN `enable_server_restriction` int(11) default 0 AFTER `flags`;
ALTER TABLE `store_categories` ADD COLUMN `priority` INT(11) NOT NULL DEFAULT '0' AFTER `id`;
ALTER TABLE `store_categories` ADD COLUMN `enable_server_restriction` int(11) default 0 AFTER `web_color`;

CREATE TABLE IF NOT EXISTS `store_versions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `mod_name` VARCHAR(64) NOT NULL,
  `mod_description` VARCHAR(64) NULL DEFAULT NULL,
  `mod_ver_convar` VARCHAR(64) NULL DEFAULT NULL,
  `mod_ver_number` VARCHAR(64) NOT NULL,
  `server_id` VARCHAR(64) NOT NULL,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `UNIQUE PLUGIN ON SERVER` (`mod_ver_convar`, `server_id`)
) COLLATE='utf8_general_ci' ENGINE=InnoDB AUTO_INCREMENT=7;

CREATE TABLE IF NOT EXISTS `store_servers_items` (
  `id` int(11) NOT NULL auto_increment,
  `item_id` int(11),
  `server_id` int(11),
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `store_servers_categories` (
  `id` int(11) NOT NULL auto_increment,
  `category_id` int(11),
  `server_id` int(11),
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

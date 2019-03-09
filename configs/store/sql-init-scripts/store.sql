CREATE TABLE IF NOT EXISTS `store_categories` (
  `id` int(11) NOT NULL auto_increment,
  `priority` int(11) default NULL,
  `display_name` varchar(32) NOT NULL,
  `description` varchar(128) default NULL,
  `require_plugin` varchar(32) default NULL,
  `web_description` text default NULL,  
  `web_color` varchar(10) default NULL,
  `enable_server_restriction` int(11) default 0,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS `store_items` (
  `id` int(11) NOT NULL auto_increment,
  `priority` int(11) default NULL,
  `name` varchar(32) NOT NULL,
  `display_name` varchar(32) NOT NULL,
  `description` varchar(128) default NULL,
  `web_description` text,
  `type` varchar(32) NOT NULL,
  `loadout_slot` varchar(32) default NULL,
  `price` int(11) NOT NULL,
  `category_id` int(11) NOT NULL,
  `attrs` text default NULL, 
  `is_buyable` tinyint(1) NOT NULL DEFAULT '1',
  `is_tradeable` tinyint(1) NOT NULL DEFAULT '1',
  `is_refundable` tinyint(1) NOT NULL DEFAULT '1',
  `expiry_time` int(11) NULL,
  `flags` varchar(11) default NULL,
  `enable_server_restriction` int(11) default 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS `store_loadouts` (
  `id` int(11) NOT NULL auto_increment,
  `display_name` varchar(32) NOT NULL,
  `game` varchar(32) default NULL,
  `class` varchar(32) default NULL,
  `team` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

INSERT INTO `store_loadouts` (`display_name`, `game`, `class`, `team`) VALUES
('A', NULL, NULL, NULL),
('B', NULL, NULL, NULL),
('C', NULL, NULL, NULL);

CREATE TABLE IF NOT EXISTS `store_users` (
  `id` int(11) NOT NULL auto_increment,
  `auth` int(11) NOT NULL,
  `name` varchar(32) NOT NULL,
  `credits` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `auth` (`auth`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `store_users_items` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  `acquire_date` DATETIME NULL,
  `acquire_method` ENUM('shop', 'trade', 'gift', 'admin', 'web') NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `store_users_items_loadouts` (
  `id` int(11) NOT NULL auto_increment,
  `useritem_id` int(11) NOT NULL,
  `loadout_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

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
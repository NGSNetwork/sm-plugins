// SQL queries for the weddings_proposals table.

char sql_createProposals[] = "CREATE TABLE IF NOT EXISTS `weddings_proposals` (`source_name` varchar(64) DEFAULT NULL, `source_id` varchar(64) NOT NULL DEFAULT '' PRIMARY KEY, `target_name` varchar(64) DEFAULT NULL, `target_id` varchar(64) NOT NULL DEFAULT '') ENGINE=InnoDB DEFAULT CHARSET=utf8;";

char sql_resetProposals[] = "DELETE FROM weddings_proposals;";	
	
char sql_addProposal[] = "INSERT INTO weddings_proposals VALUES ('%s', '%s', '%s', '%s');";
	
char sql_deleteProposalsSource[] = "DELETE FROM weddings_proposals WHERE source_id = '%s';";
	
char sql_deleteProposalsTarget[] = "DELETE FROM weddings_proposals WHERE target_id = '%s';";
	
char sql_getProposals[] = "SELECT source_name, source_id FROM weddings_proposals WHERE target_id = '%s';";
	
char sql_getAllProposals[] = "SELECT * FROM weddings_proposals WHERE source_id ='%s' OR target_id = '%s';";
	
char sql_updateProposalSource[] = "UPDATE weddings_proposals SET source_name = '%s' WHERE source_id = '%s';";
	
char sql_updateProposalTarget[] = "UPDATE weddings_proposals SET target_name = '%s' WHERE target_id = '%s';";
	

// SQL queries for the weddings_marriages table.

char sql_createMarriages[] = "CREATE TABLE IF NOT EXISTS `weddings_marriages` (`source_name` varchar(64) DEFAULT NULL, `source_id` varchar(64) NOT NULL DEFAULT '' PRIMARY KEY, `target_name` varchar(64) DEFAULT NULL, `target_id` varchar(64) NOT NULL DEFAULT '', `score` int(11) unsigned DEFAULT NULL, `timestamp` int(11) unsigned DEFAULT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8;";
	
char sql_resetMarriages[] = "DELETE FROM weddings_marriages;";
	
char sql_addMarriage[] = "INSERT INTO weddings_marriages VALUES ('%s', '%s', '%s', '%s', %i, %i);";	
	
char sql_revokeMarriage[] = "DELETE FROM weddings_marriages WHERE source_id ='%s' OR target_id = '%s';";	
	
char sql_getMarriage[] = "SELECT * FROM weddings_marriages WHERE source_id = '%s' OR target_id = '%s';";	
	
char sql_getMarriages[] = "SELECT * FROM weddings_marriages ORDER BY score DESC LIMIT %i;";	
	
char sql_updateMarriageSource[] = "UPDATE weddings_marriages SET source_name = '%s' WHERE source_id = '%s';";
	
char sql_updateMarriageTarget[] = "UPDATE weddings_marriages SET target_name = '%s' WHERE target_id = '%s';";
	
char sql_updateMarriageScore[] = "UPDATE weddings_marriages SET score = (score + 1) WHERE source_id = '%s' OR target_id = '%s';";
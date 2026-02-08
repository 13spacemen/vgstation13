/datum/migration/sqlite/ss13_prefs/_031
	id = 31
	name = "Widescreen Prefs"

/datum/migration/sqlite/ss13_prefs/_031/up()
	var/mig1
	var/mig2
	var/mig3
	if(!hasColumn("client","widescreen"))
		mig1 = execute("ALTER TABLE `client` ADD COLUMN widescreen INTEGER DEFAULT 1")
	if(!hasColumn("client","auto_fit_viewport"))
		mig2 = execute("ALTER TABLE `client` ADD COLUMN auto_fit_viewport INTEGER DEFAULT 1")
	if(!hasColumn("client","pixel_size"))
		mig3 = execute("ALTER TABLE `client` ADD COLUMN pixel_size REAL DEFAULT 0")
	return mig1 && mig2 && mig3

/datum/migration/sqlite/ss13_prefs/_031/down()
	var/mig1
	var/mig2
	var/mig3
	if(hasColumn("client","widescreen"))
		mig1 = execute("ALTER TABLE `client` DROP COLUMN widescreen")
	if(hasColumn("client","auto_fit_viewport"))
		mig2 = execute("ALTER TABLE `client` DROP COLUMN auto_fit_viewport")
	if(hasColumn("client","pixel_size"))
		mig3 = execute("ALTER TABLE `client` DROP COLUMN pixel_size")
	return mig1 && mig2 && mig3

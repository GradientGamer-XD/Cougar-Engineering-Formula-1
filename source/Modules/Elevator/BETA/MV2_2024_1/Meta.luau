return {

	Name = 'MV2_2024_1', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'October 24th, 2024 release of MV2. Candidate 1', -- Describe the version's name here
	VersionNumber = 4, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'Adds a startup delay when the elevator begins to start moving from an idle state.',
			'Improved queue direction behavior'
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Queue direction would be set to the incorrect direction when leveling at a floor; this should no longer happen.'
		},
	},

}
return {

	Name = 'MV2_2024_2', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'November 11th, 2024 release of MV2. Candidate 2', -- Describe the version's name here
	VersionNumber = 4, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'Implements a pause feature to door slowdown.',
			'Improved queue directioning once aqgain.'
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Queue direction would be set to the incorrect direction when leveling at a floor; this should no longer happen.'
		},
	},

}
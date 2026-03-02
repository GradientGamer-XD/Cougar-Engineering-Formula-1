return {

	Name = '14_10_2024_1', -- Name of the version (dd_mm_yyyy_version number)
	Description = 'October 14th, 2024 release (candidate 1).', -- Describe the version's name here
	VersionNumber = 3, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'This version adds motor sounds for hydraulic-style elevators.',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Improved safety features of doors, elevators should no longer randomly go out-of-service after doors have fully closed.'
		},
	},

}
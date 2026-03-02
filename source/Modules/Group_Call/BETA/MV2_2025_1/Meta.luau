return {

	Name = 'MV2_2025_1', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'January 11th, 2025, release.', -- Describe the version's name here
	VersionNumber = 5, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Audit allocator to ignore elevators that are out of service or are on fire service.',
		},
	},

}
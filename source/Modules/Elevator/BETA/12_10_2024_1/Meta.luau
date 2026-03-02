return {

	Name = '12_10_2024_1', -- Name of the version (dd_mm_yyyy_version number)
	Description = 'October 12th, 2024 release (candidate 1).', -- Describe the version's name here
	VersionNumber = 2, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'This version contains various hotfixes, such as nudge mode & improved door safeties',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Door safety not accounting for door sides'
		},
	},

}
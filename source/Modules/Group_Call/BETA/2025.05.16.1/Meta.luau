return {

	Name = '2025.05.16.1', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'May 16th, 2025 release. Candidate 1', -- Describe the version's name here
	VersionNumber = 6, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fixes made to accommodate for the new elevator controller variable framework. No longer uses deprecated variables. This version will NOT work on older versions of an elevator controller!',
		},
	},

}
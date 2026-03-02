return {

	Name = '2025.09.17.1', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'September 17th, 2025 release of MXV2. Candidate 1', -- Describe the version's name here
	VersionNumber = 13, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fixes API, Remote & Data_API not always generating on initial startup.',
			'Fixes to fire recall & phase 2.',
			'Button illumination transition feature is now disabled by default.'
		},
	},

}
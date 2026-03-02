return {

	Name = '2025.11.04.2', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'November 4th, 2025 release of MXV2. Candidate 2', -- Describe the version's name here
	VersionNumber = 14, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'Improved door safety.'
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fixed \'tables cannot be cyclic\' error caused by Signal module.',
			'Fixed door safety bugs.'
		},
	},

}
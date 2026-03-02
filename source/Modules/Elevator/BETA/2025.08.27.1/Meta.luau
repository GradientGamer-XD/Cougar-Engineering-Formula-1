return {

	Name = '2025.08.27.1', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'August 27th, 2025 release of MXV2. Candidate 1', -- Describe the version's name here
	VersionNumber = 12, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'This release contains new additions to button configuration.',
			'Adds custom individual button colors.',
			'Adds button reset behavior, reset delay, and illumination transitioning.',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fix- Call buttons not firing button click events to the API.'
		},
	},

}
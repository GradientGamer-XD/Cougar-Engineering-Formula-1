return {

	Name = '2025.09.03.1', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'September 3rd, 2025 release of MXV2. Candidate 1', -- Describe the version's name here
	VersionNumber = 2, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'This release contains new additions to button configuration.',
			'Adds custom individual button colors.',
			'Adds button reset behavior, reset delay, and illumination transitioning.',
			'Script reboot capability- The elevator can be fully reset by disabling & re-enabling the controller loader script.'
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fix- Call buttons not firing button click events to the API.',
			'Fixes nudge signal audio not looping when the doors nudge',
		},
	},

}
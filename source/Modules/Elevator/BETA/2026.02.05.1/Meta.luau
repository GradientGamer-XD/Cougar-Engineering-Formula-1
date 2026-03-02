return {

	Name = '2026.02.05.1', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'February 5th, 2026 release. Candidate 1', -- Describe the version's name here
	VersionNumber = 16, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'Adds inspection API.',
			'Expands on access mode API; adds acceleration and deceleration rate.'
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Door sensors are no longer active when elevator in in fire service or out of service.'
		},
	},

}
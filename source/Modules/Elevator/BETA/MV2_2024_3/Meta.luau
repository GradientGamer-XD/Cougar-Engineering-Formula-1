return {

	Name = 'MV2_2024_3', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'December 7th, 2024 release of MXV2. Candidate 3', -- Describe the version's name here
	VersionNumber = 5, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'Adds custom button input conditionals. This allows for things such as floor lockout & more.',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'All welded players are now unwelded if the elevator safety brakes.',
			'When the hoistway doors have been opened by a door key & the car doors have been fully closed, the elevator will no longer return to normal service.'
		},
	},

}
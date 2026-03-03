return {

	Name = '2026.03.02-FORMULA1', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'Formula 1 BETA Build 1', -- Describe the version's name here
	VersionNumber = 2, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'Adds inspection API.',
			'Expands on access mode API; adds acceleration and deceleration rate.',
			'First Formula 1 System released',
			'Offical Source Repo: https://github.com/GradientGamer-XD/Cougar-Engineering-Formula-1/'
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Door sensors are no longer active when elevator in in fire service or out of service.'
		},
	},

}
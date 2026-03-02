return {

	Name = '2025.04.22.1', -- Name of the version (yyyy.mm.dd.canidate_#)
	Description = 'April 22nd, 2025 release of MXV2. Candidate 1', -- Describe the version's name here
	VersionNumber = 9, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'Renamed all function names (such as \'controller.go_to_floor\') to \'controller.GoToFloor\' (following PascalCase format)',
			'Renamed all internal variable names (such as \'controller.stat_values\') to \'controller.StatValues\' & all of its dependencies to follow PascalCase format.',
			'<b>Warning messages will emit in Output/Console when deprecated variables/functions are indexed. Please use the new casing for new work.</b>',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Speed no longer goes any higher than its previous speed when decelerating.',
			'Removed \'Desired call cannot be equal (==) to current floor\' warning message when requesting a call with the same floor as the elevator car due to faults.'
		},
	},

}
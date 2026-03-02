return {

	Name = 'MV2_2025_1', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'January 11th, 2025 release of MXV2. Candidate 1', -- Describe the version's name here
	VersionNumber = 6, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Addition/implementation, removal, and more comments go here.
			'',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fixes an issue with elevators not responding to same-floor calls due to the queue entry not being removed.',
			'Fixes \'Failed to load sound rbxassetid://0: Request asset was not found\' sound errors.',
			'Fixes an issue with multiple door sides causing a safety brake trigger.',
			'Fix bugs with parking.',
			'Fixes an issue where same-floor hall call does not respond if the elevator is already leveling on the floor.',
			'Fixes an issue with queue direction not being set properly when the elevator begins to slow down at a floor.',
			'Fixes \"GetBoundingBox is not a valid member of Folder\" error.',
			'Other various bug fixes.',
		},
	},

}
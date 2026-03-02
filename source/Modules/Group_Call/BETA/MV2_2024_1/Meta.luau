return {

	Name = 'MV2_2024_1', -- Name of the version (MV2_yyyy_release candiate #)
	Description = 'October 24th, 2024 release.', -- Describe the version's name here
	VersionNumber = 3, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'Minor updates such as more state detection.',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Allocator now checks for & ignores any cars that are out of service.',
			'If no elevator is initially found, the allocator will repeatedly check for an available car every second until one has been found. The call button will time out after 30 seconds if no car is found.'
		},
	},

}
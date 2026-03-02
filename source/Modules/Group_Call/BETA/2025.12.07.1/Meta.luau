return {

	Name = '2025.12.07.1', -- Name of the version (yyyy.mm.dd.release candiate #)
	Description = 'December 7th, candidate 1', -- Describe the version's name here
	VersionNumber = 9, -- The specified version number for this release
	Key = '', -- Key used to use this version, should it be locked. Leave as '' to unlock this version.
	Notes = {
		Comments = { -- Miscallaneous comments go here.
			'Allocator rewrite to implement scoring system to improve allocation logic.',
		},
		Patches = { -- Patches (i.e. bug fixes, important adjustments, etc.) go here.
			'Fixes allocation inaccuracies.'
		},
	},

}
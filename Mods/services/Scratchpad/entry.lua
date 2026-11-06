declare_plugin("Scratchpad",
{
	dirName = current_mod_path,
	developerName = _("rkusa"),
	developerLink = _("https://github.com/rkusa/dcs-scratchpad"),
	displayName = _("Scratchpad"),
	state = "installed",
	version = "1.0.0",
	Options = {
		{
			name = _("Scratchpad"),
			nameId = "Scratchpad",
			dir = "Options",
			CLSID = "{Scratchpad options}",
			icon = current_mod_path.."/Options/icon.png",
			allow_in_simulation = true;
		},
	},
})

plugin_done()

local DbOption = require("Options.DbOption")

return {
	showUpdates = DbOption.new():setValue(true):checkbox(),
	flashKeys = DbOption.new():setValue(true):checkbox(),
	fontSize = DbOption.new():setValue(14):slider(DbOption.Range(10, 20)),
	hotkey = DbOption.new():setValue("Ctrl+Shift+."):combo({
		DbOption.Item(_('Ctrl+Shift+.')):Value("Ctrl+Shift+."),
		DbOption.Item(_('Ctrl+Shift+,')):Value("Ctrl+Shift+,"),
		DbOption.Item(_('Ctrl+Shift+/')):Value("Ctrl+Shift+/"),
		DbOption.Item(_('Ctrl+Shift+;')):Value("Ctrl+Shift+;"),
		DbOption.Item(_('Ctrl+Shift+[')):Value("Ctrl+Shift+["),
		DbOption.Item(_('Ctrl+Shift+]')):Value("Ctrl+Shift+]"),
		DbOption.Item(_('Ctrl+Alt+.')):Value("Ctrl+Alt+."),
		DbOption.Item(_('Ctrl+Alt+,')):Value("Ctrl+Alt+,"),
		DbOption.Item(_('Ctrl+Alt+/')):Value("Ctrl+Alt+/"),
		DbOption.Item(_('Ctrl+Shift+Space')):Value("Ctrl+Shift+Space"),
		DbOption.Item(_('Ctrl+Shift+Home')):Value("Ctrl+Shift+Home"),
		DbOption.Item(_('Ctrl+Shift+End')):Value("Ctrl+Shift+End"),
		DbOption.Item(_('Shift+Alt+.')):Value("Shift+Alt+."),
		DbOption.Item(_('Shift+Alt+,')):Value("Shift+Alt+,"),
		DbOption.Item(_('Shift+Alt+/')):Value("Shift+Alt+/"),
	}),
}

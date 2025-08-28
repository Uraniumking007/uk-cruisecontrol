fx_version "cerulean"

description "Speed Limiter"
author "UraniumKing"
version '1.0.0'
-- repository 'https://github.com/UraniumKing/fivem-speed-limiter'

lua54 'yes'

games {
  "gta5",
  "rdr3"
}

ui_page 'web/build/index.html'

client_scripts {
  'client/config.lua',
  'client/utils.lua',
  'client/client.lua'
}

files {
	'web/build/index.html',
	'web/build/**/*',
}
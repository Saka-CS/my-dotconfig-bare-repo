
local function get_motherboard_name()
	local file = io.open("/sys/devices/virtual/dmi/id/board_name")

	if not file then
		print("motherboard_name doesn't exist")
		return nil
	end

	local motherboard_name = file:read("*a")
	file:close()
	motherboard_name = motherboard_name:gsub("^%s*(.-)%s*$", "%1")

	return motherboard_name
end
local motherboard_name = get_motherboard_name()


if motherboard_name ~= "MS-16JF" then return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [[
          ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
          ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z    
          ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z       
          ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z         
          ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║           
          ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝           

[ @saka404 at Twitch & YouTube ]
        ]],
      },
    },
  },
}
else return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [[
          ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
          ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z    
          ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z       
          ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z         
          ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║           
          ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝           

[ @saka404 ]
        ]],
      },
    },
  },
}
end

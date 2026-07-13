return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = function()
				require("base16-colorscheme").setup({
					base00 = "#090f24",
					base01 = "#111a38",
					base02 = "#1b458f",
					base03 = "#34456f",
					base04 = "#dbe4ff",
					base05 = "#f5f7ff",
					base06 = "#ffffff",
					base07 = "#ffffff",
					base08 = "#e5484d",
					base09 = "#ff6369",
					base0A = "#f9d616",
					base0B = "#65c466",
					base0C = "#4fd6be",
					base0D = "#4f8cff",
					base0E = "#9d7cd8",
					base0F = "#f9d616",
				})
			end,
		},
	},
}

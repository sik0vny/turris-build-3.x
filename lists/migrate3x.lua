--[[
This is migration script used to migrate/update system from Turris OS 3.x to 4.x.

We have to update updater first so we do immediate replan and update only updater
itself.
]]

if not version_match or not self_version or version_match(self_version, "<63.0") then

	local board
	if model:match("[Oo]mnia") then
		board = "omnia"
	elseif model:match("^[Tt]urris$") then
		board = "turris"
	else
		DIE("Unsupported Turris model: " .. tostring(model))
	end

	--[[
	We provide access to only HBS repository and to only minimal set of feeds. We
	don't need anything more to update updater.
	]]
	Repository("turris", "https://repo.turris.cz/hbs/packages/" .. board, {
		subdirs = { "base", "core", "packages", "turrispackages"}
	})

	Install('updater-ng', { critical = true })

	Package('updater-ng', {
		replan = 'immediate',
		deps = { 'libgcc', 'tos3to4-early' }
	})
	--[[
	Updater package does not depend on libgcc but it requires it and dependency
	breaks otherwise.

	We added additional dependency in form of package tos3to4-early which contains
	script to migrate updater configuration. That means that when new updater is
	being installed the configuration is also migrated at the same time.
	]]

end

--[[
This same package as in Turris OS 3.x which contains script pulling in this
script. The difference is that Turris OS 4.x contains version 2.x of this package
to ensure update and that it does not contain noted script. Instead it contains
script migrating system configuration. That way configuration is updated and at
the same time this script is left out of all following updater executions because
tos3to4 is going to be removed.
]]
Install("tos3to4")
Package("tos3to4", { replan = "later" })

--[[
We are potentially migrating from uClibc so reinstall everything depending on it.
]]
Package("libc", { abi_change_deep = true })
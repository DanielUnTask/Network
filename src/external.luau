--!strict
local Packages = script.Parent.Parent

--- Dependencies
local Task = require(Packages.Task)
local Trove = require(Packages.Trove)
local Signal = require(Packages.Signal)

return {
	Task = Task,
	Trove = Trove,
	Signal = Signal,
}

local fs = require("dos/filesystem.sys")

local args, ops = cmd.parse(...)
local path = nil
local verbose = false

if ops.help or #args == 0 then
  print("Useage cd [dir]")
  return
end

path = args[1]

local resolved = cmd.resolve(path)
if not fs.exists(resolved) then
  io.stderr:write("Invalid directory\n")
  return 1
end

path = resolved
local result, reason = cmd.setWorkingDirectory(path)
if not result then
  io.stderr:write(reason)
  return 1
end

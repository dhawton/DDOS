local component = require("component")
local shell = require("shell")
local fs = require("filesystem")

local eeprom = component.eeprom

local function writeRom()
  local file = assert(fs.open(args[1], "rb"))
  local bios = file:read("*a")
  file:close

  print("Flashing EEPROM")
  print("Do not switch off your computer")

  eeprom.set(bios)

  print("Done.")
end

writeRom()

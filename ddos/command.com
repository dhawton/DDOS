if not DDOS then error("Kernel missing") return end

local dos = require("dos")
local fs = require("filesystem")
local cmd = {}

_G.cmd = cmd

local tArgs={...}
local history = {}

if DDOS.cmdHistory then history = DDOS.cmdHistory end
if DDOS.cmdDrive then fs.drive.setcurrent(DDOS.cmdDrive) end

local function comma_format(amt)
  local form = amt
  while true do
    form, k = string.gsub(form, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then
      break
    end
  end
  return form
end

local function pad(txt)
  txt = tostring(txt)
  return #txt >= 2 and txt or "0" .. txt
end
local function nod(n)
  return n and (tostring(n):gsub("(%.[0-9]+)0+$", "%1")) or "0"
end

local function runprog(file, parts)
	DDOS.cmdHistory = history
	DDOS.cmdDrive = fs.drive.getcurrent()
	table.remove(parts, 1)
	error({[1]="INTERRUPT", [2]="RUN", [3]=file, [4]=parts})
end

local function runbat(file, parts)
	error("Not yet Implemented!")
end

local function listdrives()
	for letter, address in fs.drive.list() do
		print(letter, address)
	end
end

local function lables()
	for letter, address in fs.drive.list() do
		print(letter, component.invoke(address, "getLabel"))
	end
end

local function label(parts)
	proxy, reason = fs.proxy(parts[2])
	if not proxy then
		print(reason)
		return
	end
	if #parts < 3 then
		print(proxy.getLabel() or "no label")
	else
		local result, reason = proxy.setLabel(parts[3])
		if not result then print(reason or "could not set label") end
	end
end

local function outputFile(file, paged)
  local handle, reason = filesystem.open(file)
  if not handle then
    error(reason, 2)
  end
  local buffer = ""
  repeat
    local data, reason = filesystem.read(handle)
    if not data and reason then
      error(reason)
    end
    buffer = buffer .. (data or "")
  until not data
  filesystem.close(handle)
  if paged then printPaged(buffer)
  else print(buffer) end
end

function cmd.dir()
  print(" ")
  print("  Volume in drive " .. filesystem.drive.getcurrent())
  print("  Volume Serial Number " .. filesystem.drive.toAddress(filesystem.drive.getcurrent()))
  print("  Directory of " .. filesystem.drive.getcurrent() .. ":" .. (dos.getenv("PWD") or "/"))
  print(" ")
  local f = 0
  local d = 0
  local totsize = 0
  for file in filesystem.list((dos.getenv("PWD") or "/")) do
    local da = os.date("*t", filesystem.lastModified(dos.getenv("PWD") .. "/" .. file))
    local h = da.hour
    local ap = "AM"
    if h > 12 then
      h = h - 12
      ap = "PM"
    end
    local md = string.format("%s-%s-%s  %s:%s %s", da.year, pad(nod(da.month)), pad(nod(da.day)), pad(nod(h)), pad(nod(da.min)), ap)
    if filesystem.isDirectory((dos.getenv("PWD") or "") .. "/" .. file) then
      print(md .. "    <DIR>         " .. file)
      d = d + 1
    else
      print(md .. "  " .. text.padLeft(comma_format(tostring(filesystem.size(dos.getenv("PWD") .. "/" .. file))), 15) .. " " .. file)
      totsize = totsize + filesystem.size(dos.getenv("PWD") .. "/" .. file)
      f = f + 1
    end
  end
  print(" ", f .. " file(s)", comma_format(tostring(totsize)) .. " bytes")
  print(" ", d .. " dir(s)", comma_format(tostring(filesystem.spaceTotal() - totsize)) .. " bytes free")
  print(" ")
end

function print_r ( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

local function runline(line)
	line = text.trim(line)
	if line == "" then return true end
	parts = text.tokenize(line)
	command = string.lower(text.trim(parts[1]))
	--drive selector
	if #command == 2 then
    if string.sub(command, 2, 2) == ":" then
      filesystem.drive.setcurrent(string.sub(command, 1, 1))
      dos.setenv("PWD", "/")
      return true
    end
  end
	--internal commands
	if command == "exit" then history = {} return "exit" end
	if command == "cls" then term.clear() return true end
	if command == "ver" then print(_OSVERSION) return true end
	if command == "mem" then print(math.floor(computer.totalMemory()/1024).."k RAM, "..math.floor(computer.freeMemory()/1024).."k Free") return true end
	if command == "dir" then cmd.dir() return true end
	if command == "intro" then intro() return true end
	if command == "disks" then listdrives() return true end
	if command == "discs" then listdrives() return true end
	if command == "drives" then listdrives() return true end
	if command == "labels" then lables() return true end
	if command == "label" then if parts[2] then label(parts) return true else print("Invalid Parameters") return false end end
	if command == "type" then outputFile(parts[2]) return true end
	if command == "more" then outputFile(parts[2], true) return true end
	if command == "echo" then print(table.concat(parts, " ", 2)) return true end
  if command == "dos" then print_r(dos) return true end
	if command == "cmds" then printPaged([[
Internal Commands:
exit --- Exit the command interpreter, Usually restarts it.
cls ---- Clears the screen.
ver ---- Outputs version information.
mem ---- Outputs memory information.
dir ---- Lists the files on the current disk.
cmds --- Lists the commands.
intro -- Outputs the introduction message.
drives - Lists the drives and their addresses.
labels - Lists the drives and their labels.
label -- Sets the label of a drive.
echo --- Outputs its arguments.
type --- Like echo, but outputs a file.
more --- Like type, but the output is paged.
copy --- Copies a file.
move --- Moves a file.]]) print() return true end
	if command == "" then return true end
	if command == nil then return true end
	--external commands and programs
	command = parts[1]
	if filesystem.exists(command) then
		if not filesystem.isDirectory(command) then
			if text.endswith(command, ".lua") then runprog(command, parts) return true end
			runprog(command, parts) return true
		end
	end
	if filesystem.exists(command .. ".lua") then
		if not filesystem.isDirectory(command .. ".lua") then
			runprog(command .. ".lua", parts)
			return true
		end
	end
  if filesystem.exists("/dos/" .. command .. ".lua") then
    if not filesystem.isDirectory("/dos/" .. command .. ".lua") then
      runprog("/dos/" .. command .. ".lua", parts)
      return true
    end
  end
	print("Bad command or filename")
	return false
end

function cmd.setWorkingDirectory(dir)
  checkArg(1, dir, "string")
  dir = fs.canonical(dir):gsub("^$", "/"):gsub("(.)/$", "%1")
  if fs.isDirectory(dir) then
    dos.setenv("PWD", dir)
    return true
  else
    return nil, "Not a directory"
  end
end

function cmd.getWorkingDirectory()
  return dos.getenv("PWD") or "/"
end

local env = {}

function cmd.runline(line)
	local result = table.pack(pcall(runline, line))
	if result[1] then
		return table.unpack(result, 2, result.n)
	else
		if type(result[2]) == "table" then if result[2][1] == "INTERRUPT" then error(result[2]) end end
		printErr("ERROR:", result[2])
	end
end

function cmd.parse(...)
  local params = table.pack(...)
  local args=  {}
  local options = {}
  local doneWithOptions = false

  for i = 1, params.n do
    local param = params[i]
    if not doneWithOptions and type(param) == "string" then
      if param == "--" then
        doneWithOptions = true
      elseif unicode.sub(param, 1, 2) == "--" then
        if param:match("%-%-(.-)=") ~= nil then
          options[param:match("%-%-(.-)=")] = param:match("=(.*)")
        else
          options[unicode.sub(param, 3)] = true
        end
      elseif unicode.sub(param, 1, 1) == "-" and param ~= "-" then
        for j = 2, unicode.len(param) do
          options[unicode.sub(param, j, j)] = true
        end
      else
        table.insert(args, param)
      end
    else
      table.insert(args, param)
    end
  end
  return args, options
end

function cmd.resolve(path, ext)
  if ext then
    checkArg(2, ext, "string")
    local where = findFile(path, ext)
    if where then
      return where
    else
      return nil, "File not found"
    end
  else
    if unicode.sub(path, 1, 1) == "/" then
      return fs.canonical(path)
    else
      return fs.concat(cmd.getWorkingDirectory(), path)
    end
  end
end

if cmd.runline(table.concat(tArgs, " ")) == "exit" then return end

while true do
	term.write(filesystem.drive.getcurrent() ..":" .. cmd.getWorkingDirectory() .. ">")
	local line = term.read(history)
	while #history > 10 do
		table.remove(history, 1)
	end
	if cmd.runline(line) == "exit" then return end
end

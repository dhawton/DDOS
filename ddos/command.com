if not DDOS then
  error("Missing kernel")
  return
end

local shell = {}
local tArgs = {...}
local continue

local history = {}
if DDOS.cmdHistory then history = DDOS.cmdHistory end
if DDOS.cmdDrive then fs.drive.setCurrent(DDOS.cmdDrive) end

local function runprog(file, parts)
  DDOS.cmdHistory = history
  DDOS.cmdDrive = fs.drive.getCurrent()
  table.remove(parts, 1)
  error({[1] = "INTERRUPT", [2] = "RUN", [3] = file, [4] = parts})
end

local function listdrives()
  for l, addr in fs.drive.list() do
    print(l, addr)
  end
end

local function labels()
  for l, addr in fs.drive.list() do
    print(l, component.invoke(addr, "getLabel"))
  end
end

local function label(parts)
  proxy, reason = fs.proxy(parts[2])
  if not proxy then
    print (reason)
    return
  end

  if #parts < 3 then
    print (proxy.getLabel() or "No label")
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

local function runline(line)
  line = text.trim(line)
  if line == "" then return true end
  parts = text.tokenize(line)
  command = string.lower(text.trim(parts[1]))

  if #command == 2 then
    if string.sub(command, 2, 2) == ":" then
      filesystem.drive.setCurrent(string.sub(command, 1,1))
      return true
    end
  end

  if command == "" or command == nil then return true end
  r,p = cmdExists(command)
  if r then
    runprog(p, parts)
    return true
  end

  print("Bad command or file name")
  return false
end

function shell.runline(line)
  local result = table.pack(pcall(runline, line))
  if result[1] then
    return table.unpack(result, 2, result.n)
  else
    if type(result[2]) == "table" and result[2][1] == "INTERRUPT" then
      error(result[2])
    end
    printErr("ERROR:", result[2])
  end
end

if shell.runline(table.concat(tArgs, " ")) == "exit" then return end

while true do
  term.write(filesystem.drive.getCurrent() .. "> ")
  local line = term.read(history)
  while #history > 10 do
    table.remove(history, 1)
  end
  if shell.runline(line) == "exit" then return end
end

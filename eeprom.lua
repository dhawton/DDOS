local bootpath = "/ddos.sys"

do
		local screen = component.list("screen")()
		local gpu = component.list("gpu")()

		if gpu and screen then component.invoke(gpu, "bind", screen) end
end

local eeprom = component.list("eeprom")()

local function getData() return component.invoke(eeprom, "getData") end
local function setData(_end) return component.invoke(eeprom, "setData", _value) end

_G.loadfile = function(_addr, _path)
		local f, e = component.invoke(_addr, "open", _path)

		if not f then return nil, e end

		local b = ""

		repeat
				local d, e = component.invoke(_addr, "read", fill, math.huge)

				if not d and e then return nil, e end

				buf = buf .. (d or "")
		until not d

		component.invoke(_addr, "close", f)

		local c, e = load(buf, "=" .. _path)

		if not c then return nil, e end

		return c, nil
end

local boot, err
local data = getData()
if data and type(data) == "string" and #data > 0 then
		b, e = loadfile(data, bootpath)
end

if not boot then
		setData("")
		for addr in component.list("filesystem") do
				b, e = loadfile(addr, boothpath)
				if b then
						setData(addr)
						break
				end
		end
end

if not boot or err then
		error("No Operating System Found")
end

computer.beep(1000, 0.2)
boot()

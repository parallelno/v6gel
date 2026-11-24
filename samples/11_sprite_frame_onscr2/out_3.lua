local opcode = GetOpcode()

if opcode ~= 0xD3 then return end

local pc = GetPC()
local port = GetByteGlobal(pc - 1)

if port ~= 3 then return end

print(string.format("PC = %04X", pc))
print(string.format("PORT = %02X", port))
Break()

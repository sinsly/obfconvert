--[[

    Author: sinsly

    License: MIT

    Github: https://github.com/sinsly

--]]

-- obfconvert.lua
-- Builds an obfuscated string + reverse mapping (as before),
-- prints them, and copies the same text to the clipboard using setclipboard(copiedtext).
-- replace src's [[ ]] with your script you want to convert

local src = [[
print('hi')
-- add your full script here
]]

-- build the set of unique characters used in src
local seen = {}
local chars = {}
for i = 1, #src do
    local c = src:sub(i,i)
    if not seen[c] then
        seen[c] = true
        table.insert(chars, c)
    end
end

-- build tokens: fixed-length tokens "~XX" (tilde + two hex digits)
local mapping = {}          -- original_char -> token
local rev_mapping = {}      -- token -> original_char
for i, ch in ipairs(chars) do
    local token = string.format("~%02X", i) -- ~01, ~02, ~1A, etc
    mapping[ch] = token
    rev_mapping[token] = ch
end

-- build obfuscated string: replace each char with token
local obf_parts = {}
for i = 1, #src do
    local c = src:sub(i,i)
    obf_parts[#obf_parts+1] = mapping[c]
end
local obf_string = table.concat(obf_parts)

-- prepare printable lines (so we can both preview and copy the same content)
local out_lines = {}
table.insert(out_lines, "--[[\n")
table.insert(out_lines, "    Author: sinsly\n")
table.insert(out_lines, "    License: MIT\n")
table.insert(out_lines, "    Github: https://github.com/sinsly\n")
table.insert(out_lines, "--]]\n")
table.insert(out_lines, 'obf_string = [[' .. obf_string .. ']]\n')

table.insert(out_lines, "rev_mapping = {")
-- use a deterministic order for nicer output: collect tokens and sort
local tokens = {}
for token in pairs(rev_mapping) do table.insert(tokens, token) end
table.sort(tokens)
for _, token in ipairs(tokens) do
    local orig = rev_mapping[token]
    -- escape backslashes and quotes so the pasted table is valid Lua
    local esc = orig:gsub("\\", "\\\\"):gsub("\r", "\\r"):gsub("\n", "\\n")
    -- use %q to quote the token and orig safely
    table.insert(out_lines, string.format("  [%q] = %q,", token, esc))
end
table.insert(out_lines, "}\n")
table.insert(out_lines, "-- DONE --")

-- join into one string for printing and copying
local final_text = table.concat(out_lines, "\n")

-- print to output (console)
print(final_text)

-- copy to clipboard
local ok, err = pcall(function()
    if type(setclipboard) == "function" then
        setclipboard(final_text)
    else
        error("setclipboard not available in this environment")
    end
end)

if ok then
    print("\n-- Copied to clipboard (setclipboard) --")
else
    print("\n-- Could not copy to clipboard: " .. tostring(err) .. " --")
end


-- decompile starts here if you are interested <3
-- reconstruct the original source from obf_string + rev_mapping
local function decompile_to_string()
    if type(obf_string) ~= "string" then
        print("-- no obf_string present to decompile --")
        return nil
    end
    if type(rev_mapping) ~= "table" then
        print("-- no rev_mapping present to decompile --")
        return nil
    end

    local parts = {}
    local i = 1
    local len = #obf_string
    -- tokens are fixed-length: tilde + two hex chars => length 3
    while i <= len do
        local token = obf_string:sub(i, i+2)
        local ch = rev_mapping[token]
        if ch == nil then
            -- if we encounter an unknown token, insert a placeholder and continue
            ch = "?"
        end
        parts[#parts+1] = ch
        i = i + 3
    end

    local reconstructed = table.concat(parts)
    return reconstructed
end

-- run the reconstructed source instead of printing it.
local function run_decompiled()
    local reconstructed = decompile_to_string()
    if not reconstructed then
        print("-- nothing reconstructed; aborting execution --")
        return nil
    end

    -- choose loader: Lua 5.2+ has load; 5.1 uses loadstring
    local loader = load or loadstring
    if not loader then
        print("-- no load/loadstring available in this Lua environment --")
        return nil
    end

    -- try to compile the reconstructed code into a chunk
    local chunk, compile_err = loader(reconstructed, "decompiled_chunk")
    if not chunk then
        print("-- compile error in decompiled code: " .. tostring(compile_err))
        return nil
    end

    -- execute compiled chunk safely with pcall
    local ok, runtime_err = pcall(chunk)
    if ok then
        print("-- Decompiled code executed successfully --")
        return true
    else
        print("-- Error running decompiled code: " .. tostring(runtime_err))
        return nil
    end
end

-- automatically run the decompiled code when this script is executed for testing purposes
run_decompiled()

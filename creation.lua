--[[

    Author: sinsly
    License: MIT
    Github: https://github.com/sinsly

--]]

-- build an obfuscated string + reverse mapping 
-- prints them, and copies the same text to the clipboard
-- remove example obf_string and rev_mapping in the script to call from src
-- replace src's [[ ]] with your script you want to convert

obf_string = "~01~02~03~04~05~06~07~08~03~09~05~08~03~0A~09~05~0B~0A~05~09~0C~0D~02~0E~0B~0F~07~10"

rev_mapping = {
  ["~01"] = "p",
  ["~02"] = "r",
  ["~03"] = "i",
  ["~04"] = "n",
  ["~05"] = "t",
  ["~06"] = "(",
  ["~07"] = "'",
  ["~08"] = "h",
  ["~09"] = " ",
  ["~0A"] = "s",
  ["~0B"] = "e",
  ["~0C"] = "w",
  ["~0D"] = "o",
  ["~0E"] = "k",
  ["~0F"] = "d",
  ["~10"] = ")",
}


local src = src or [[
print('hi this test worked 2')]]

-- detect whether obf_string and rev_mapping look valid
local function has_valid_obf()
    if type(obf_string) ~= "string" or #obf_string == 0 then return false end
    if type(rev_mapping) ~= "table" then return false end
    -- quick sanity: tokens are ~XX repeated, length should be multiple of 3
    if (#obf_string % 3) ~= 0 then return false end
    return true
end

-- build obf_string + rev_mapping from src
local function generate_from_src(s)
    local seen = {}
    local chars = {}
    for i = 1, #s do
        local c = s:sub(i,i)
        if not seen[c] then
            seen[c] = true
            table.insert(chars, c)
        end
    end

    local mapping = {}
    local rev = {}
    for i, ch in ipairs(chars) do
        local token = string.format("~%02X", i) -- ~01, ~02, ...
        mapping[ch] = token
        rev[token] = ch
    end

    local obf_parts = {}
    for i = 1, #s do
        local c = s:sub(i,i)
        obf_parts[#obf_parts+1] = mapping[c]
    end
    local obf = table.concat(obf_parts)

    return obf, rev
end

-- obf_string + rev_mapping
local function build_pasteable_block(obf, rev)
    local out_lines = {}
    table.insert(out_lines, "--[[\n")
    table.insert(out_lines, "    Author: sinsly\n")
    table.insert(out_lines, "    License: MIT\n")
    table.insert(out_lines, "    Github: https://github.com/sinsly\n")
    table.insert(out_lines, "--]]\n")
    table.insert(out_lines, 'obf_string = ' ..'"'.. obf .. '"\n')
    table.insert(out_lines, "rev_mapping = {")

    local tokens = {}
    for token in pairs(rev) do table.insert(tokens, token) end
    table.sort(tokens)
    for _, token in ipairs(tokens) do
        local orig = rev[token]
        -- use %q to safely quote strings (handles newlines and backslashes)
        table.insert(out_lines, string.format("  [%q] = %s,", token, string.format("%q", orig)))
    end

    table.insert(out_lines, "}\n") -- close table and add trailing newline
    local final_text = table.concat(out_lines, "\n")
    return final_text
end

-- copy to clipboard where available
local function try_setclipboard(text)
    local ok, err = pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(text)
            return true
        end
        -- some exploit environments expose syn and syn.set_clipboard or similar
        if type(syn) == "table" and type(syn.set_clipboard) == "function" then
            syn.set_clipboard(text)
            return true
        end
        error("setclipboard not available in this environment")
    end)
    return ok, err
end

-- if obf_string/rev_mapping are missing or invalid, generate them from src
if not has_valid_obf() then
    print("No valid obf_string/rev_mapping found: generating from src...")
    local obf, rev = generate_from_src(src)
    obf_string = obf
    rev_mapping = rev

    local block = build_pasteable_block(obf, rev)
    print("Generated obf_string + rev_mapping (pasteable block):\n")
    print(block)

    local ok, err = try_setclipboard(block)
    if ok then
        print("The obf_string + rev_mapping block was copied to clipboard.")
    else
        print("Could not copy to clipboard: " .. tostring(err))
    end
else
    print("Using existing obf_string + rev_mapping.")
end

local dcm = loadstring(game:HttpGet("https://raw.githubusercontent.com/sinsly/m40fuscation/main/connect.lua"))()


local function has_valid_obf()
    if type(obf_string) ~= "string" or #obf_string == 0 then return false end
    if type(rev_mapping) ~= "table" then return false end
    if (#obf_string % 3) ~= 0 then return false end
    return true
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

local function rand_hex(len)
    local out = {}
    for i = 1, len do out[#out+1] = string.format("%02X", math.random(0,255)) end
    return table.concat(out)
end

local function generate_from_src(s, mode_num)
    if math and math.randomseed then
        local seed = (type(tick) == "function" and tick() or os.time and os.time() or 1)
        math.randomseed((seed * 1103515245 + 12345) % 2147483647)
        for i = 1, 5 do math.random() end
    end

    local seen = {}
    local chars = {}
    for i = 1, #s do
        local c = s:sub(i,i)
        if not seen[c] then
            seen[c] = true
            table.insert(chars, c)
        end
    end

    local fake_count = 0
    if mode_num == 1 then fake_count = 36 end
    if mode_num == 2 then fake_count = 96 end

    local used = {}
    local rev = {}
    local mapping = {}

    local function pick_num()
        local num
        repeat
            num = math.random(1, 255)
        until not used[num]
        used[num] = true
        return num
    end

    for _, ch in ipairs(chars) do
        local n = pick_num()
        local token = string.format("~%02X", n)
        mapping[ch] = token
        rev[token] = ch
    end

    local obf_parts = {}
    for i = 1, #s do
        local c = s:sub(i,i)
        obf_parts[#obf_parts+1] = mapping[c]
    end
    local obf = table.concat(obf_parts)

    for i = 1, fake_count do
        local n = pick_num()
        local token = string.format("~%02X", n)
        local kind = math.random(1, 5)
        if kind == 1 then
            local wlen = math.random(3,8)
            local t = {}
            for j = 1, wlen do t[#t+1] = string.char(math.random(97,122)) end
            rev[token] = table.concat(t)
        elseif kind == 2 then
            rev[token] = tostring(math.random(0,999999))
        elseif kind == 3 then
            local t = {}
            for j = 1, math.random(2,5) do
                t[#t+1] = string.char(math.random(97,122))
            end
            rev[token] = table.concat(t, ".")
        elseif kind == 4 then
            local a = {}
            for j = 1, math.random(1,3) do a[#a+1] = ('"%s":%d'):format(string.char(math.random(97,122)), math.random(0,99)) end
            rev[token] = "{" .. table.concat(a, ",") .. "}"
        else
            rev[token] = string.char(math.random(33,126))
        end
    end

    local m40v1_list = {}

    local base_names = {"AES", "RSA", "KDF", "HMAC", "PBKDF", "FOA"}
    for _, base in ipairs(base_names) do
        local t = {}
        local nitems = math.random(2, 6)
        for i = 1, nitems do
            local k = ("_%s_%d"):format(base:sub(1,2), i)
            local vchoice = math.random(1,4)
            if vchoice == 1 then
                t[k] = tostring(math.random(0,9999))
            elseif vchoice == 2 then
                local s_len = math.random(3,8)
                local s = {}
                for z = 1, s_len do s[#s+1] = string.char(math.random(97,122)) end
                t[k] = table.concat(s)
            elseif vchoice == 3 then
                t[k] = ("0x%X"):format(math.random(0, 65535))
            else
                t[k] = ("%q"):format(("M40%sX"):format(base:sub(1,1)))
            end
        end
        local rand_suffix = rand_hex(2)
        local name = ("_M40V1_%s_%s"):format(base, rand_suffix)
        m40v1_list[#m40v1_list+1] = {name = name, value = t}
    end

    local faux_funcs = {}
    local fcount = (mode_num == 2) and 6 or 4
    for i = 1, fcount do
        local fname = ("_%s_f%02d_%s"):format(string.char(math.random(97,122)), math.random(1,99), rand_hex(2))
        local body_parts = {}
        local lines = math.random(1,4)
        for l = 1, lines do
            local r = math.random(1,3)
            if r == 1 then
                body_parts[#body_parts+1] = ("    local v%d = %d"):format(l, math.random(0,9999))
            elseif r == 2 then
                body_parts[#body_parts+1] = ("    local s%d = %q"):format(l, (string.char(math.random(97,122)):rep(math.random(2,6))))
            else
                body_parts[#body_parts+1] = ("    local t%d = %q"):format(l, (string.char(math.random(97,122)):rep(math.random(6,12))))
            end
        end
        faux_funcs[#faux_funcs+1] = {name = fname, body = body_parts}
    end

    return obf, rev, m40v1_list, faux_funcs
end

local function build_pasteable_block(obf, rev, mode_num, m40v1_list, faux_funcs)
    local tokens = {}
    for t in pairs(rev) do tokens[#tokens+1] = t end

    if mode_num == 1 then
        table.sort(tokens)
    else
        shuffle(tokens)
    end

    local out = {}
    out[#out+1] = "--[["
    out[#out+1] = "    Author: sinsly"
    out[#out+1] = "    License: MIT"
    out[#out+1] = "    Github: https://github.com/sinsly"
    out[#out+1] = "]]"

    out[#out+1] = "obf_string = " .. string.format("%q", obf)
    out[#out+1] = "rev_mapping = {"

    if mode_num == 2 then
        for i = 1, math.random(2, 5) do
            local tkn = string.format("~%02X", math.random(1,255))
            local val = ("%q"):format(("hdr_%02d"):format(math.random(1,99)))
            out[#out+1] = ("  [%q] = %s,"):format(tkn, val)
        end
    end

    for _, tkn in ipairs(tokens) do
        local v = rev[tkn]
        out[#out+1] = string.format("  [%q] = %s,", tkn, string.format("%q", v))
    end

    out[#out+1] = "}"

    for _, h in ipairs(m40v1_list or {}) do
        out[#out+1] = ""
        out[#out+1] = ("local %s = {"):format(h.name)
        local keys = {}
        for k in pairs(h.value) do keys[#keys+1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = h.value[k]
            if type(v) == "string" then
                out[#out+1] = ("    [%q] = %s,"):format(k, string.format("%q", v))
            else
                out[#out+1] = ("    [%q] = %s,"):format(k, tostring(v))
            end
        end
        out[#out+1] = "}"
    end

    for _, f in ipairs(faux_funcs or {}) do
        out[#out+1] = ""
        out[#out+1] = ("local function %s()"):format(f.name)
        for _, line in ipairs(f.body) do out[#out+1] = line end
        out[#out+1] = "end"
    end

    local final = table.concat(out, "\n")
    return final
end

local function try_setclipboard(text)
    local ok, err = pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(text)
            return true
        end
        if type(syn) == "table" and type(syn.set_clipboard) == "function" then
            syn.set_clipboard(text)
            return true
        end
        error("setclipboard not available in this environment")
    end)
    return ok, err
end

if not has_valid_obf() then
    print("No valid obf_string/rev_mapping found: generating from src...")

    local mode_num = getgenv().obf_filter or 1
    if mode_num ~= 1 and mode_num ~= 2 then mode_num = 1 end

    local obf, rev, m40v1_list, faux_funcs = generate_from_src(src, mode_num)
    obf_string = obf
    rev_mapping = rev

    local block = build_pasteable_block(obf, rev, mode_num, m40v1_list, faux_funcs)
    print(("Generated obf_string + rev_mapping (mode %d):\n"):format(mode_num))
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

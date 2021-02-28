--[[
    An addon for mpv-file-browser which uses powershell commands to parse native directories

    This is slower than the default parser for local drives, but faster for network drives
    The drive_letters array below is used to list the drives to use this parser for
]]--

--list the drive letters to use here (case sensitive)
local drive_letters = {
    "Y", "Z"
}

local mp = require "mp"

local wn = {
    priority = 109,
    name = "file"
}

local drives = {}
for _, letter in ipairs(drive_letters) do
    drives[letter] = true
end

local function command(args)
    local cmd = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    })

    return cmd.status == 0 and cmd.stdout or nil
end

function wn:can_parse(directory)
    return not self.get_protocol(directory) and drives[ directory:sub(1,1) ]
end

function wn:parse(directory)
    local list = {}
    local files = command({"powershell", "-noprofile", "-command", [[
        $dirs = Get-ChildItem -LiteralPath ]]..string.format("%q", directory)..[[ -Directory
        $files = Get-ChildItem -LiteralPath ]]..string.format("%q", directory)..[[ -File

        foreach ($n in $dirs.Name) {
            $n += "/"
            $u8clip = [System.Text.Encoding]::UTF8.GetBytes($n)
            [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
            Write-Host ""
        }

        foreach ($n in $files.Name) {
            $u8clip = [System.Text.Encoding]::UTF8.GetBytes($n)
            [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
            Write-Host ""
        }
    ]]})

    if not files then return nil end

    for str in files:gmatch("[^\n\r]+") do
        local is_dir = str:sub(-1) == "/"
        if is_dir and self.valid_dir(str) then
            table.insert(list, {name = str, type = "dir"})
        elseif self.valid_file(str) then
            table.insert(list, {name = str, type = "file"})
        end
    end

    return self.sort(list), {filtered = true, sorted = true}
end

return wn


--[[
    etc_weakpasswords.lua
    Version 1.0 by 4c3T, aided in large by ChatGPT

    Checks online registered users against an external
    weak-password list.

    Sends private warnings to affected users and reports
    detections to online OPs (level 100).
]]

-- IMPORTS
local io = require "io"
local os = require "os"
local string = require "string"

-- SETTINGS
local PASSWORD_FILE = "scripts/weak_passwords.txt"

local CHECK_INTERVAL = 60 * 60
local REMINDER_INTERVAL = 24 * 60 * 60

local OP_LEVEL = 100

local MESSAGE =
    "Security warning: Your current password has been identified as weak or unsafe. " ..
    "Please change your password as soon as possible."

-- INTERNAL
local weak_passwords = {}
local last_notified = {}
local next_check = 0

-- LOAD PASSWORD LIST
local function load_passwords()
    local file = io.open(PASSWORD_FILE, "r")

    if not file then
        hub.debug("etc_weakpasswords: Cannot open password list: " .. PASSWORD_FILE)
        return false
    end

    weak_passwords = {}

    for line in file:lines() do
        local password = string.match(line, "^%s*(.-)%s*$")

        if password ~= "" and string.sub(password, 1, 1) ~= "#" then
            weak_passwords[password] = true
        end
    end

    file:close()
    return true
end

-- REPORT TO ONLINE OPS
local function report_ops(nick, timestamp)
    local message = string.format(
        "[WeakPassword] User: %s | Time: %s",
        nick,
        os.date("%Y-%m-%d %H:%M:%S", timestamp)
    )

    for _, op in pairs(hub.getusers()) do
        if op:level() == OP_LEVEL then
            op:reply(message, hub.getbot(), hub.getbot())
        end
    end
end

-- CHECK ONLINE USERS
local function check_users()
    if not load_passwords() then
        return
    end

    local registered = hub.getregusers()
    local users_by_nick = {}

    for _, reg in pairs(registered) do
        if reg.is_bot ~= 1 and reg.nick and reg.password then
            users_by_nick[reg.nick] = reg
        end
    end

    local now = os.time()

    for _, user in pairs(hub.getusers()) do
        if user:isregged() then
            local nick = user:firstnick()
            local reg = users_by_nick[nick]

            if reg and weak_passwords[reg.password] then
                local last = last_notified[nick] or 0

                if now - last >= REMINDER_INTERVAL then
                    user:reply(MESSAGE, hub.getbot(), hub.getbot())

                    report_ops(nick, now)

                    last_notified[nick] = now
                end
            end
        end
    end
end

-- START
hub.setlistener("onStart", {},
    function()
        next_check = os.time() + 10
        hub.debug("** Loaded etc_weakpasswords 1.1 **")
    end
)

-- TIMER
hub.setlistener("onTimer", {},
    function()
        local now = os.time()

        if now >= next_check then
            next_check = now + CHECK_INTERVAL
            check_users()
        end
    end
)

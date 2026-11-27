
--[[
    etc_public_email_check.lua
    Version 1.0

    Checks client-reported email addresses against a public
    email provider domain list.

    Sends a private warning to matching users and reports
    detections to OpChat.

    Does not access the local user database.
    Created by 4c3T with help of ChatGPT
]]

-- IMPORTS
local io = require "io" --Disable for <v3.2.0
local string = require "string" --Disable for <v3.2.0

local report = hub.import("etc_report")

-- SETTINGS
local DOMAIN_FILE = "scripts/data/etc_public_email_domains.txt"

local USER_MESSAGE =
    "\n\n\n Security notice: Your client is advertising an email address from a public email provider.\n" ..
    "This hub flags major public email providers as a privacy and security precaution.\n" ..
    "This is an informational notice only; your account is not restricted.\n"

-- INTERNAL
local public_domains = {}
local notified_users = {}
local last_hourly_check = os.time()

-- LOAD DOMAIN LIST
local function load_domains()
    local file, err = io.open(DOMAIN_FILE, "r")

    if not file then
        hub.debug("etc_public_email_check: Cannot open domain list: " ..
            DOMAIN_FILE .. " (" .. tostring(err) .. ")")
        return false
    end

    public_domains = {}

    for line in file:lines() do
        local domain = string.match(line, "^%s*(.-)%s*$")

        if domain ~= "" and string.sub(domain, 1, 1) ~= "#" then
            public_domains[string.lower(domain)] = true
        end
    end

    file:close()

    local count = 0
    for _ in pairs(public_domains) do
        count = count + 1
    end

    hub.debug("etc_public_email_check: Loaded " .. tostring(count) .. " domains")

    return true
end

-- MATCH EXACT DOMAIN OR SUBDOMAIN
local function find_public_domain(domain)
    for blocked_domain in pairs(public_domains) do
        if domain == blocked_domain or
            string.sub(domain, -(string.len(blocked_domain) + 1)) == "." .. blocked_domain then
            return blocked_domain
        end
    end

    return nil
end

-- CHECK USER EMAIL
local function check_user(user)
    local sid = user:sid()

    if notified_users[sid] then
        return
    end

    local nick = user:firstnick() or "Unknown"
    local email = user:email()

    if not email or email == "" then
        return
    end

    email = string.lower(hub.escapefrom(email))

    local domain = string.match(email, "@([^@]+)$")

    if not domain then
        return
    end

    domain = string.match(domain, "^%s*(.-)%s*$")

    local matched_domain = find_public_domain(domain)

    if matched_domain then
        notified_users[sid] = true

        user:reply(USER_MESSAGE, hub.getbot(), hub.getbot())

        local opchat_message =
            "[PublicEmailCheck] User " ..
            hub.escapefrom(nick) ..
            " was notified by PM. Public email domain: " ..
            domain

        if report then
            report.send(true, false, true, 0, opchat_message)
        end

        hub.debug("etc_public_email_check: Notified " .. nick)
    end
end

-- CHECK CLIENT EMAIL ON LOGIN
hub.setlistener("onLogin", {},
    function(user)
        check_user(user)
        return nil
    end
)

-- CLEAR NOTIFICATION STATUS ON LOGOUT
hub.setlistener("onLogout", {},
    function(user)
        notified_users[user:sid()] = nil
        return nil
    end
)

-- HOURLY CHECK
hub.setlistener("onTimer", {},
    function()
        local now = os.time()

        if os.difftime(now, last_hourly_check) >= 3600 then
            last_hourly_check = now

            local users = hub.getusers()

            for _, user in pairs(users) do
                check_user(user)
            end

            hub.debug("etc_public_email_check: Hourly check completed")
        end

        return nil
    end
)

-- STARTUP
load_domains()

hub.debug("** Loaded etc_public_email_check 1.0 **")

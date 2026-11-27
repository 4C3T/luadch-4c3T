
--[[
    etc_public_email_check.lua
    Version 1.0

    Checks the email address advertised by the connecting client.
    Uses client INF information only; does not access the local user database.
    Sends a private notice to the user and a notification to OpChat.
]]

-- IMPORTS
local report = hub.import("etc_report")

-- SETTINGS
local DOMAIN_FILE = "scripts/data/etc_public_email_domains.txt"
local CHECK_INTERVAL = 3600

local USER_MESSAGE =
    "\n\n\n Security notice: Your client is advertising an email address from a public email provider. " ..
    "This hub flags major public email providers as a privacy and security precaution. " ..
    "This is an informational notice only; your account is not restricted."

-- INTERNAL
local public_domains = {}
local notified_users = {}
local last_hourly_check = 0

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
            domain = string.lower(domain)
            public_domains[domain] = true
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

    if not matched_domain then
        return
    end

    local notified = user:reply(
        USER_MESSAGE,
        hub.getbot(),
        hub.getbot()
    )

    if notified then
        notified_users[sid] = true

        if report then
            local nick = hub.escapefrom(
                user:firstnick() or user:nick() or "Unknown"
            )

            local opchat_message =
                "[PublicEmailCheck] User " .. nick ..
                " was notified by PM. Public email domain: " .. domain

            report.send(true, false, true, 0, opchat_message)
        end
    else
        hub.debug("etc_public_email_check: Could not send PM to " ..
            tostring(user:firstnick() or "unknown"))
    end
end

-- CHECK CLIENT-REPORTED EMAIL ON LOGIN
hub.setlistener("onLogin", {},
    function(user)
        check_user(user)
        return nil
    end
)

-- CLEAR SESSION STATUS ON LOGOUT
hub.setlistener("onLogout", {},
    function(user)
        notified_users[user:sid()] = nil
        return nil
    end
)

-- HOURLY CHECK OF ONLINE USERS
hub.setlistener("onTimer", {},
    function()
        local now = os.time()

        if os.difftime(now, last_hourly_check) >= CHECK_INTERVAL then
            last_hourly_check = now

            for _, user in pairs(hub.getusers()) do
                check_user(user)
            end
        end

        return nil
    end
)

-- STARTUP
load_domains()
last_hourly_check = os.time()

hub.debug("** Loaded etc_public_email_check 1.0 **")

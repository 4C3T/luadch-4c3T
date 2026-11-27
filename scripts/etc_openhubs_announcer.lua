--[[
    
        etc_openhubs_announcer.lua v0.2 by Motnahp
        
        - Script made clearer + editable parts added
        - Now, only users who are currently connected are checked after a certain amount of time, rather than at the moment of login. 
		>> Edit 'recheckdelay' to adjust this (default is set to 2 minutes).

            
       etc_openhubs_announcer.lua v0.1 by Motnahp
       
       - Checks users for public hubs shortly after login
            >> edit delaylogin for this (set to 120 seconds by default)
			
		- Added code correction for luadch v3.1.15 -Original code was commented out as faulty by 4c3T, Nov 27-2026
       
]]--

--[[ Settings ]]--       

-- Do not edit --
local scriptname = "etc_openhubs_announcer_v0.2"
local hub_bot = hub.getbot()
local min = 1

-------------
local bantime = 60 * 60
-------------
local start = os.time()
--funtions
local reportItTo
local check
-->> The following settings can be edited -->>
local recheck = true -- Should all users be checked at intervals of recheckdelay? (true = Yes / false = No)
local maxchecklvl = 100 -- Maximum level up to which the test should be carried out (including)
local reportlvl = 100 -- Minimum level to be reported (including)
local warnUser = true -- Should the user be notified / warned that he has OpenHubs open? (true = yes / false = no) 
local sendMain = false -- Should the main chat be reported to the operating theaters? (true = yes / false = no) 
local sendPM = true -- Should PM be reported to the OPs? (true = yes / false = no) 
local recheckdelay = 30 --> Check time delay (in minutes)

-- Message to the user

-------------


local banmsg = [[

	You have been kicked for using public hubs - This is not allowed while being on MovieLover's Hub!
	Ideally, you shouldn't be on any private hub if you insist on hanging around public unsafe hubs.
	Repeating this might get your account disabled. If you don't see the hazard, disconnect public hubs,
	reconnect here and ask the hub owner or any of the Allied forces-ops and they'll tell you why!
	]]




-----------


local badmsg = [[ 

        You're in a public hub according to your client tag
        We don't tolerate public hubs connected to client who
	in turn are connected to private hubs!
	In the event your computer is seized, all information
	regarding hubs, users and file info would then be available
	to people who is not supposed to have that.

	In some cases, law enforcement agencies could also
	force you to help them by providing information
	for lesser punishment (pleabargin) or similar.
	This would most likely be done in the USA, as
	their laws for baiting are very different than
	that of countries in Europe.

	Regardless, you (or anyone else caught up in this mess!)
	could become a target because of this.
        

	Anyone can visit public hub lists online and see
	users name, e-mail (in some cases) and share size

        So, in other words, don't use the same client, IP
	or share if/when you are on a public hub!
	Also, don't use the same nickname, and whatever
	you do, never intermix private with piracy.
	Don't use your email address, real name etc!
        ]]
-- Message to the OPs
local opmsg = "<Public hubs detected!> "
-- the layout of the message can also be changed in line 81

--<< End of the editable part --<<

recheckdelay = recheckdelay * min

--[[   Code   ]]--     

hub.setlistener("onTimer", {},
    function()
        -- if recheck and (os.difftime( os.time( ) - start ) >= recheckdelay) then -- Doesn't work /4c3T
		if recheck and (os.difftime(os.time(), start) >= recheckdelay) then
            for sid, user in pairs(hub.getusers()) do
                check(user)
            end
            start = os.time( )
        end
        return nil
    end
) 
 
 -- function check(user) Doesn't work
check = function(user)
    local hn, hr, ho = user:hubs()
    local open = hn or "unknown"
    local user_nick = user:nick()
    local user_level = user:level()
    local level = cfg.get("levels")[user_level] or "Unreg"
    local msg =""
    
    if user_level <= maxchecklvl then
        if (open > 0) or (open == "unknown") then         
            if warnUser then
                user:reply(badmsg, hub.getbot(), hub.getbot())
		user:kill( "ISTA 232 " .. banmsg .. bantime .. "\n", "TL-1" )
            end
            msg = msg..opmsg..user_nick.." has subsequently been kicked because of it" -- Line that is visible to the OPs
            reportItTo(reportlvl, msg)
        end
    end
end

-- function reportItTo(lvl, msg) -- Doesn't work /4c3T
reportItTo = function(lvl, msg)

    for sid, user in pairs(hub.getusers()) do
        local targetuser = user:level()
        if targetuser >= lvl then
            if sendPM then
                user:reply(msg, hub_bot, hub_bot)
		
            end
            if sendMain then
                user:reply(msg, hub_bot)
            end
        end
    end
end

hub.debug( "** Loaded " .. scriptname .. ".lua **" )

--[[   End    ]]--       
--[[
        ExtendedBackground.lua
--]]

local ExtendedBackground, dbg, dbgf = Background:newClass{ className = 'ExtendedBackground' }



--- Constructor for extending class.
--
--  @usage      Although theoretically possible to have more than one background task,
--              <br>its never been tested, and its recommended to just use different intervals
--              <br>for different background activities if need be.
--
function ExtendedBackground:newClass( t )
    return Background.newClass( self, t )
end



--- Constructor for new instance.
--
--  @usage      Although theoretically possible to have more than one background task,
--              <br>its never been tested, and its recommended to just use different intervals
--              <br>for different background activities if need be.
--
function ExtendedBackground:new( t )
    local interval
    local minInitTime
    local idleThreshold
    if app:getUserName() == '_AuthorsName_' and app:isAdvDbgEna() then
        interval = .1
        idleThreshold = 1
        minInitTime = 3
    else
        interval = .5
        idleThreshold = 2 -- (every other cycle) appx 1/sec.
        -- default min-init-time is 10-15 seconds or so.
    end    
    local o = Background.new( self, { interval=interval, minInitTime=minInitTime, idleThreshold=idleThreshold } )
    return o
end



--- Initialize background task.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:init( call )
    local s, m = LrTasks.pcall( renamer.init, renamer )
    if s then    
        self.initStatus = true
        -- this pref name is not assured nor sacred - modify at will.
        if not app:getPref( 'background' ) then -- check preference that determines if background task should start.
            self:quit() -- indicate to base class that background processing should not continue past init.
        end
    else
        self.initStatus = false
        app:logError( "Unable to initialize due to error: " .. str:to( m ) )
        app:show( { error="Unable to initialize - check log file for details." } )
    end
end



--- Perform background photo processing.
--
--  @param target lr-photo to be processed, may be most-selected, selected, filmstrip, or any (if idle processing).
--  @param call background call object.
--  @param idle (boolean) true iff called from idle-processing considerator.
--
--  @usage set enough-for-now when time intensive operations have occurred such that subsequent idle-processing would be too much for now (ignored if idle processing).
--         <br>this is a non-critical value, but may help prevent Lightroom UI jerkiness in some cases.
--
function ExtendedBackground:processPhoto( target, call, idle )
    self.enoughForNow = false -- set to true if time consuming processing took place, which is not expected to happen again next time.
end



--- Background processing method.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:process( call )

    local photo = catalog:getTargetPhoto() -- most-selected.
    self.enoughForNow = false
    if photo then
        self:processPhoto( photo, call, false ) -- set self--enough-for-now if time intensive processing encountered which does not always occur.
    end
    if not self.enoughForNow then
        self:considerIdleProcessing( call )
    end
    
end
    


return ExtendedBackground

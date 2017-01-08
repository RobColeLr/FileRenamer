--[[
        Renamer.lua
--]]


local Renamer, dbg, dbgf = Object:newClass{ className = "Renamer", register = true } -- jre debug, and fmt debug funcs, as you prefer.



--- Constructor for extending class.
--
function Renamer:newClass( t )
    return Object.newClass( self, t )
end


--- Constructor for new instance.
--
function Renamer:new( t )
    return Object.new( self, t )
end



function Renamer:init()    
    
    if not app:isPluginEnabled() then
        app:show{ info="Plugin must be enabled in order for '^1' to function (via 'Library Menu -> Plugin Extras').",
            subs = app:getPluginName(),
            actionPrefKey = "plugin must be enabled"
        }
        return -- return uninitialized.
    else
        -- proceed to attempt initialization.
        -- Note: non-nil filenamePreset member indicates initialization was done OK.
    end

    local filename = str:fmtx( "^1.lrtemplate", app:getPluginName() )
    local template = LrPathUtils.child( _PLUGIN.path, filename )
    
    -- Note: although original method for finding filename-preset dir will work here, since it's writing to *both* places if appropriate,
    -- then reading back in *either* place, this hap-hazard method is deprecated in favor of it's version 2.
    --[[ this until 19/May/2014 4:36:
    local withCat, dir, altDir = lightroom:getFilenamePresetDir() -- whacky, but worky... ### get-preset-dir?
    local dirs
    if withCat ~= nil then
        if withCat then
            app:log( "There are filename presets stored with catalog in '^1'", dir ) -- but that does not necessarily mean they are currently being used there.
            Debug.pauseIf( not str:is( dir ) or not str:is( altDir ), dir, altDir )
            dirs = { dir, altDir }
        else -- I think if there are none stored with catalog, then the proper target can not possibly be with catalog.
            app:log( "Filename presets are stored in Lightroom app-data (not with catalog) in '^1'", dir )
            dirs = { dir } -- Note: I just checked - as soon as ya say: "store presets with catalog", it creates the dir in catalog, which remains even if you then uncheck it.
        end
    else
        app:logWarning( "Not clear where filename presets are stored just yet, hopefully after template copy / Lr restart it will become clear." )
        dirs = { dir, altDir }
    end
    --]]
    -- this after 19/May/2014 4:37: (###2: keep eye on it).
    local dir, oops = lightroom:getPresetDir( "Filename Templates" )
    if not dir then app:error( oops ) end
    local dirs = { dir }
    -------------------------------
    local presets = LrApplication.filenamePresets()
    local pluginName = app:getPluginName()
    app:logv( "Looking for filename preset named '^1'", pluginName )
    for k, v in pairs( presets ) do
        if str:isEqualIgnoringCase( k, pluginName ) then
            app:log( "Got requisite filename preset." )
            self.filenamePreset = v -- UUID on win7/64-Lr4, but doc says could be path - hmmm......
            break
        else
            app:logv( "'^1' is not it...", k )
        end
    end
    if not self.filenamePreset then
        if #dirs > 1 then
            app:logWarning( "Not clear if presets are stored with catalog or not, attempting to cover all bases..." )
        end
        local goodNuff = false
        for i, tDir in ipairs( dirs ) do
            -- Debug.pause( tDir, fso:existsAsDir( tDir ) )
            if fso:existsAsDir( tDir ) then
                local destPath = LrPathUtils.child( tDir, filename )
                local s, m = fso:copyFile( template, destPath, true, true ) -- do not create dir - it's existence has been pre-validated - do overwrite file though, even if it already exists.
                if s then
                    app:log( "Copied requisite filename template '^1' to '^2'.", template, destPath )
                    goodNuff = true
                else
                    app:logWarning( "Unable to copy requisite filenameing template (^1) to Lightroom preset folder: '^2'.", template, tDir )
                    app:show{ warning="Unable to copy requisite filenameing template (^1) to Lightroom's filename presets folder: '^2'.",
                        subs = { filename, tDir },
                    }
                end
            else
                app:logv( "No filename preset dir here: ^1", tDir )
            end
        end
        if goodNuff then
            local f, qual = lightroom:prepareForRestart() -- restart with active catalog.
            if f then
                local typ = 'confirm'
                local msg = "Requisite filenaming template was just copied to Lightroom's filenaming templates folder - Lightroom must be restarted.\n \nClick 'OK' to restart Lightroom now, or 'Cancel' if you prefer to restart manually."
                if not qual then
                    -- msg = "Restart Lightroom?"
                    --typ = 'confirm'
                else
                    msg = msg .. "\n \n" .. qual
                    --typ = 'warning'
                end
                local button = app:show{ [typ]=msg }
                if button == 'ok' then
                    f() -- execute restart function.
                end
            else
                app:log( "Unable to initiate restart programmatically, restart will have to be manual - ^1", qual )
                app:show{ warning="Requisite filenaming template was just copied to Lightroom's filenaming templates folder. You must restart Lightroom, before you can rename files using ^1",
                    subs = app:getPluginName(),
                }
            end
        else
            app:error( "Unable to setup requisite filename preset." )
        end            
    -- else hunky-dory.
    end            
end



-- common things called in service finale method.
function Renamer:_wrapOp( call )
    if call.testMode then
        app:log( "*** TEST MODE ONLY - NO CHANGES WERE BE MADE TO CATALOG (EXCEPT RENAME COLLECTION) OR PHOTO FILES" )
    else
        app:log( "*** REAL MODE - CHANGES MAY HAVE BEEN MADE TO CATALOG AS INDICATED ABOVE" )
    end
end


-- called first off upon service method entry.
function Renamer:_initOp( call )

    local s, m = background:waitForInit( 30, 10 ) -- initial delay, retry interval - only requires such a long wait when reloading upon re-export is checked.
    if not s then
        app:error( m )
    end

    call.testMode = app:getPref( 'testMode' )
    if call.testMode == true then
        app:log( "*** TEST MODE ONLY - NO CHANGES WILL BE MADE TO CATALOG (EXCEPT RENAME COLLECTION) OR PHOTO FILES" )
        --app:logVerbose( "If wasn't test mode, collection for renamed files would have been created or validated." )
    elseif call.testMode == false then
        app:log( "*** REAL MODE - CHANGES MAY BE MADE TO CATALOG AS INDICATED BELOW" )
    else
        error( "invalid test mode" )
    end

    -- now regardless of test mode
    call.renameColl = cat:assurePluginCollection( "Renamed" ) -- throws error if no can do.
    app:logVerbose( "Collection for renamed files created or validated: ^1/^2", app:getPluginName(), call.renameColl:getName() )
end



-- init for run, after clear for takeoff...
-- props only used for part-1 of rename sequence.
-- return true or nil, errm.
function Renamer:_initRun( call, photos, props )
    if props then -- rename-start
        local init = app:getPref( 'init' )
        if init ~= nil then
            if type( init ) ~= 'function' then
                app:error( "bad init - must be function" )
            end
            local errm = init{ call=call, photos=photos, props=props }
            if str:is( errm ) then
                return nil, "error message returned by init function: " .. errm
            else -- user init pref executed ok
                app:log( "init function from preset (advanced settings) executed ok" )
            end
        else
            app:logv( "No init function defined." )
        end
    -- else rename-finish: dont call pref init func.
    end
    call.fieldId = app:getPref( 'formattedMetadataFieldIdForRenaming' ) or 'headline'
    call.photos = photos
    
    -- *** UPDATE _addMetaForPhoto method too when metadata changes:
    -- this can be time consuming - consider progress scope.
    call.rawMeta = cat:getBatchRawMetadata( photos, { 'path', 'isVirtualCopy', 'masterPhoto' } )
    call.fmtMeta = cat:getBatchFormattedMetadata( photos, { 'fileName', 'copyName' } )
    
    app:log( "Using '^1' field for new filenames.", call.fieldId )
    app:logVerbose( "Filenaming preset: ^1", self.filenamePreset )
    return true
end



function Renamer:_endRun( call )
    local finale = app:getPref( 'finale' )
    if finale ~= nil then
        if type( finale ) ~= 'function' then
            app:error( "bad finale - must be function" )
        end
        local errm = finale{ call=call }
        if str:is( errm ) then
            return nil, "error message returned by finale function: " .. errm
        else -- user finale pref executed ok
            app:log( "finale function from preset (advanced settings) executed ok" )
        end
    end
end



-- guts of cleanup function which returns headlines, and clears temp storage.
-- logs move stats upon success, and returns true,
-- else logs no finale message, but returns false, err-msg.
function Renamer:_renameFinish( call )
    local nFields = 0
    assert( call.testMode ~= nil, "no test mode" )
    app:log()    
    call:setCaption( "Moving ^1 back to proper location.", call.fieldId )
    local function renameFinish( context, phase )
        for i, photo in ipairs( call.photos ) do
            repeat
                local photoPath = call.rawMeta[photo].path
                app:log( "Cleaning up ^1", photoPath )
                local isVirtualCopy = call.rawMeta[photo].isVirtualCopy
                if isVirtualCopy then
                    app:log( "Skipping virtual copy '^1'", call.fmtMeta[photo].copyName )
                    break
                end
                if fso:existsAsFile( photoPath ) then
                    -- splattn
                else
                    app:logWarning( "Missing file: ^1", photoPath )
                    break
                end
                assert( call.fmtMeta[photo], "formatted metadata is not initialized" )
                local prev = photo:getPropertyForPlugin( _PLUGIN, "temp_", nil, true ) -- version, no-throw.
                if prev == nil then
                    prev = "" -- looks like Adobe is doing same as I do: converting nil to "nil" - but in this case, it won't do...
                end
                if not call.testMode then
                    photo:setRawMetadata( call.fieldId, prev ) -- regardless
                    photo:setPropertyForPlugin( _PLUGIN, "temp_", nil ) -- unlike headline field, it is ok to set plugin metadata to nil.
                else
                    app:log( "*** TEST MODE ONLY - NO CHANGE MADE TO CATALOG OR PHOTO FILES (EXCEPT RENAME COLLECTION)" )
                end
                if str:is( prev ) then
                    app:log( "^1 data restored", call.fieldId )
                    nFields = nFields + 1
                else
                    app:log( "No ^1 to move back.", call.fieldId )
                end
            until true
            if call:isQuit() then
                app:error( "^1 has been aborted or canceled." ) -- Assures catalog not left in a half-baked state if user cancels.
            else
                call:setPortionComplete( i, #call.photos )
            end
        end        
    end
    local s, m
    if call.testMode then
        s, m = LrTasks.pcall( renameFinish ) -- assures catalog won't change.
    else
        s, m = cat:update( 15, call.name, renameFinish )
    end
    
    if s then
        app:log()
        app:log( "^1 has been moved back to it's original location.", str:nItems( nFields, str:fmtx( "^1 fields", call.fieldId ) ) )
        return true
    else
        -- app:logErr( "There has been an error: ^1 - your catalog was not altered.", m )
        -- app:show{ error="There has been an error: ^1 - your catalog was not altered.", m }
        return false, m
    end

end



-- Menu handler.
function Renamer:renameStart()
    --app:show( self:toString() .. " rename" )
    app:call( Service:new{ name="Rename Files - Start", async=true, progress={ caption="Dialog box needs attention..." }, main=function( call )

        self:_initOp( call )

        if not self.filenamePreset then
            app:show{ warning="Requisite filenameing preset not found - try restarting Lightroom." }
            call:cancel()
            return
        end
    
        local photos = catalog:getTargetPhotos()
        if #photos == 0 then
            app:show{ warning="No photos in filmstrip." }
            call:cancel()
            return
        end
        
        local renameBase = app:getPref( 'renameBase' )
        if renameBase == nil then
            app:show{ error="No rename-base function." }
            call:cancel()
            return
        end
        if type( renameBase ) ~= 'function' then
            app:show{ error="rename must be a function." }
            call:cancel()
            return
        end
        
        local presetName = app.prefMgr:getPresetName() -- current preset name.
        local viPref = app:getPref( 'viewItems' )
        local vi
        local props = LrBinding.makePropertyTable( call.context )

        if viPref ~= nil then        
            if type( viPref ) == 'function' then
                vi = viPref{ call=call, props=props }
                if vi == nil then
                    app:show{ error="no view items returned - set viewItems to nil, unless it will return view items." }
                    call:cancel()
                    return
                end
            else
                app:show{ error="viewItems must be a function." }
                call:cancel()
                return
            end
        else
            app:log( "No view items." )
        end
        
        if vi == nil then
            vi = {}
        else
            vi[#vi + 1] = vf:spacer{ height = 10 }
        end
        local ttl
        if call.testMode then
            ttl = "*** TEST MODE ONLY, NO CHANGES WILL BE MADE TO YOUR CATALOG (EXCEPT RENAME COLLECTION) OR PHOTO FILES.\n(you have to visit plugin-manager to enable real mode)"
        else
            ttl = "*** REAL MODE: CHANGES MAY BE MADE TO YOUR CATALOG, AS INDICATED IN LOG FILE UPON COMPLETION.\n(visit plugin manager if you want to try test mode first)"
        end
        vi[#vi + 1] = 
            vf:static_text {
                title = ttl,
                fill_horizontal = 1,
            }
        
        local buttons
        local collPhotos = call.renameColl:getPhotos()
        if #collPhotos > 0 then
            buttons = { dia:btn( "Yes - empty rename collection first", 'other' ), dia:btn( "Yes - add to rename collection", 'ok' ) }
            vi[#vi + 1] = vf:spacer{ height = 10 }
            vi[#vi + 1] = 
                vf:static_text {
                    title = str:fmtx( "^1 in rename collection", str:nItems( #collPhotos, "item" ) ),
                    fill_horizontal = 1,
                }
        else
            buttons = { dia:btn( "OK", 'ok' ) }
        end
        local answer = app:show{ confirm="Rename ^1 according to '^2' (plugin manager preset)?",
            subs = { str:nItems( #photos, "photos" ), presetName },
            buttons = buttons,
            viewItems = vi,
        }
        if answer == 'cancel' then
            call:cancel()
            return
        end
        
        local s, m = self:_initRun( call, photos, props )
        if s then
            -- ok - details already logged.
        else
            app:logErr( m )
            return
        end
        
        -- fall-through => it's gonna happen.
        
        local changes = {}
        local nFields = 0
        
        app:log()
        call:setCaption( "Preparing for you to rename your files..." )
        -- executes with write access if not test mode.
        local function renameStart( context, phase )
            if phase == 1 then
                if answer == 'other' then
                    if not call.testMode then
                        call.renameColl:removeAllPhotos()
                        app:log( "Rename collection cleared." )
                    else
                        local s, m = cat:update( 30, "Clear rename collection", function( context, phase )
                            call.renameColl:removeAllPhotos()
                        end )
                        if s then
                            app:log( "Rename collection cleared." )
                        else                            
                            app:error( "Unable to clear rename collection - ^1", m )
                        end
                    end
                else
                    app:log( "Rename collection not emptied." )
                end
                -- perhaps best to do all photos in one swoop, so that user does not have to figure out which photos were renamed and which not, to reselect and try again... - all or nothing this is.
                -- virtual copies? ###3 - perhaps a better handling would be to do the master, but only once: record that it was done..
                for i, photo in ipairs( call.photos ) do
                    repeat
                        local photoPath = call.rawMeta[photo].path
                        app:log( "Processing ^1", photoPath )
                        local isVirtualCopy = call.rawMeta[photo].isVirtualCopy
                        if isVirtualCopy then
                            app:log( "Skipping virtual copy '^1'", call.fmtMeta[photo].copyName )
                            break
                        end
                        if fso:existsAsFile( photoPath ) then
                            -- splattn
                        else
                            app:logWarning( "Missing file: ^1", photoPath )
                            break
                        end
                        assert( call.fmtMeta[photo], "formatted metadata is not initialized" )
                        local oldName = call.fmtMeta[photo].fileName
                        local oldBase = LrPathUtils.removeExtension( oldName )
                        local oldExt = LrPathUtils.extension( oldName )
                        assert( str:is( oldExt ), "old name has no extension" )
                        local folderPath = LrPathUtils.parent( photoPath )
                        local newBase, msg = renameBase{ call=call, photo=photo, photoPath=photoPath, folderPath=folderPath, base=oldBase, ext=oldExt }
                        if call:isQuit() then
                            app:error( "^1 aborted or canceled.", call.name )
                        end
                        if not str:is( newBase ) then
                            app:error( "No (base) name returned from rename function - ^1", str:to( msg or "nothing to add." ) ) -- toss the whole deal, if any errors - so we don't end up with a partially done job.
                        else
                            newBase = LrStringUtils.trimWhitespace( newBase )
                        end
                        if str:is( newBase ) then
                            if msg then
                                call.specialFlag = true
                                changes[#changes + 1] = photo
                            else
                                local saveBase = newBase
                                newBase = newBase:gsub( "[\\/\"<>|!:?*]", function( s )
                                    if s == "\\" then
                                        return "{bs}"
                                    elseif s == "/" then
                                        return "{fs}"
                                    elseif s == "\"" then
                                        return "{quote}"
                                    elseif s == "<" then
                                        return "{lt}"
                                    elseif s == ">" then
                                        return "{gt}"
                                    elseif s == "|" then
                                        return "{bar}"
                                    elseif s == '!' then
                                        return "{excl}"
                                    elseif s == ":" then
                                        return "{c}"
                                    elseif s == "?" then
                                        return "{q}"
                                    elseif s == "*" then
                                        return "{star}"
                                    else
                                        return "{oops}"
                                    end      
                                end )
                                if newBase ~= saveBase then
                                    app:logW( "\"{x}\" substituted for illegal characters." )
                                end
                                local newName = LrPathUtils.addExtension( newBase, oldExt ) -- probably not even used, except for logging(?)
                                if newBase == oldBase then -- Note: it *is* legal to rename file with same letters, but different case.
                                    app:log( "Name will be same: '^1'.", oldName )
                                else
                                    changes[#changes + 1] = photo
                                    if call.testMode then
                                        app:log( "Old name is: '^1' - if NOT test mode, and YOU (plugin user) renamed via '^3' template, as mentioned in the instructions, new name would be: '^2'", oldName, newName, app:getPluginName() )
                                    else
                                        app:log( "Old name is: '^1' - if YOU (plugin user) rename via '^3' template, as mentioned in the instructions, new name will be: '^2'", oldName, newName, app:getPluginName() )
                                    end
                                end
                            end
                        else
                            call.specialFlag = true -- this is a field-loader-type plugin, presumably... Reminder: it's entirely possible that special flag is NOT set, when it's a field loader preset, since metadata may never by nil, like 'path' for example.
                            app:log( "*** no new filename has been returned, so do not attempt to rename... (assuming FileRenamer is being used for some sorta \"field loader\" type functionality..." )
                        end
                        
                        local prevField = photo:getPropertyForPlugin( _PLUGIN, "temp_", nil, true ) -- version, no-throw.
                        local field = photo:getFormattedMetadata( call.fieldId )
                        
                        if call.specialFlag then
                            -- field loaders bypass temp field saving / restoral.
                        else
                            if str:is( prevField ) then
                                app:logWarning( "^1 stored in temp location: ^2", call.fieldId, prevField )
                                self.photos = photos -- this line added 24/Sep/2013 14:57 to help solve the catch-22 problem (can't start and can't finish...).
                                app:error( "File rename op still pending, shan't overwrite - you must run 'Rename Files - Finish' to clear this condition, before you will be able to rename files again." )
                                    -- the error assures the transaction is unraveled en-total by Lightroom.
                            else
                                if str:is( field ) then
                                    if field == oldBase or field == newBase then
                                        --app:error( "File rename op unfinished (^1 matches filename: ^2), shan't overwrite - you must run 'Rename Files - Finish' to clear this condition, before you will be able to rename files again.", call.fieldId, field )
                                            -- the error assures the transaction is unraveled en-total by Lightroom.
                                        app:logWarn( "File rename op probably unfinished (^1 matches filename: ^2). You may want to undo this operation (^3), then run 'Rename Files - Finish' to clear this condition.", call.fieldId, field, call.name )
                                            -- while probably an error, it's not illegal, and could even be likely if user had previously used JB's s&r/transfer plugin before coming over...
                                    else
                                        app:logVerbose( "^1 looks original.", call.fieldId )
                                    end
                                    if not call.testMode then                    
                                        photo:setPropertyForPlugin( _PLUGIN, "temp_", field )
                                    else
                                        app:log( "*** TEST MODE ONLY - NO CHANGE MADE TO CATALOG OR PHOTO FILES (EXCEPT RENAME COLLECTION)" )
                                    end
                                    nFields = nFields + 1
                                else
                                    app:log( "No ^1 to move.", call.fieldId )
                                end
                            end
                        end
    
                        if not call.testMode then  
                            -- Note: there is no "update raw metadata" method of LrMetadata object for reading first before writing, like there is for photo-(plugin)properties via CustomMetadata class.
                            -- ###3 perhaps there should be, although I think I considered this once and rejected the idea (maybe Lr has change detection built in and if no change no resources expense?) - or was I dreaming...
                            photo:setRawMetadata( call.fieldId, newBase ) -- make sure there is no extension.
                        else
                            app:log( "*** TEST MODE ONLY - NO CHANGE MADE TO CATALOG OR PHOTO FILES (EXCEPT RENAME COLLECTION)" )
                        end
                        
                    until true
                    
                    -- Note: is-quit is checked in loop body above, and results in error thrown: the idea being to let Lightroom undo rather than depending on user to undo.
                    -- It's all or nothing. To do partial, one would have to restore headline fields if probs, and deselect photo, so user did not inadvertently screw up a filename.
                    call:setPortionComplete( i, #call.photos )
                    
                end
                if not call:isQuit() then
                    return false
                end
            elseif phase == 2 then
                if #changes > 0 then
                    if not call.testMode then
                        call.renameColl:addPhotos( changes )
                    else
                        local s, m = cat:update( 30, "Populate rename collection", function( context, phase )
                            call.renameColl:addPhotos( changes )
                        end )
                        if s then
                            app:log( "Rename collection populated with ^1", str:nItems( #changes, "photos" ) )
                        else
                            app:error( "Unable to populate rename collection." )
                        end
                    end
                else
                    -- dont                
                end
                return true -- done.
            else
                app:error( "Catalog update phase is out of range: ^1", phase )
            end 
        end
        self.photos = nil -- this line added 24/Sep/2013 14:57 to help solve the catch-22 problem (can't start and can't finish...).
        local s, m
        if call.testMode then
            s, m = LrTasks.pcall( renameStart, nil, 1 ) -- phase 1
            if s then
                s, m = LrTasks.pcall( renameStart, nil, 2 ) -- phase 2
            end
        else        
            s, m = cat:update( 15, call.name, renameStart )
        end        
        if s then
            self.photos = photos -- saved for rename, finishing phase.

            if call.specialFlag then
                app:log( "It seems file renamer is being used for auxiliary purposes..." )
                app:show{ info="It seems the FileRenamer/Start function has been invoked for some sorta \"field loading\" purposes, as opposed to file renaming. If that's not true, then please correct or report problem, if it is true, then the job is (presumably) done (e.g. fields loaded)." }
            else
                app:log()
                if #changes > 0 then
                    app:log( "^1 moved to temp storage as necessary, and ^3 have been placed in ^2 field (corresponding photos were added to rename collection).", str:nItems( nFields, str:fmtx( "^1 fields", call.fieldId ) ), call.fieldId, str:nItems( #changes, "new filename bases", true ) )
                    app:show{ info="So far, so good (^1 will change), but after clicking 'OK' you must do some things:\n \n1. Rename all selected photos using the '^2' preset.\n2. Invoke: 'Rename Files - Finish' from the 'Library Menu -> Plugin Extras'.\n \nOr, if you don't want to finish the renaming, use Lightroom's 'Undo' in the 'Edit Menu', and things will be as they were...",
                        subs = { str:nItems( #changes, "filenames", true ), app:getPluginName() },
                    }
                else
                    if nFields == 0 then
                        app:log( "No changes - commencing cleanup." )
                    else
                        app:log( "^1 fields moved - but shall be moved back - no filenames to change...", nFields )
                    end
                    local s, m = self:_renameFinish( call ) -- this is required, since even unchanged files are moved to field, so batch rename works for all.
                    if s then
                        app:show{ info="No filenames changed - nothing need be done." }
                    else
                        app:logErr( "There has been an error: ^1 - consider using Lightroom's undo to get back to where you were.", m )
                    end
                end
            end
        else
            -- self.photos = nil - this line commented out 24/Sep/2013 14:56 - creates catch-22 situation (can't start & can't finish).
            app:logErr( "Unable to complete 'Rename Files - Start' due to error: ^1\n \nNo changes have been made to your catalog.", m )
            app:show{ error="Unable to complete 'Rename Files - Start' due to error: ^1\n \nNo changes have been made to your catalog.", m }
        end
        
    end, finale=function( call )
        self:_endRun( call )
        self:_wrapOp( call )
    end } )
end
    
        

-- menu handler
function Renamer:renameFinish()
    --app:show( self:toString() .. " rename" )
    app:call( Service:new{ name="Rename Files - Finish", async=true, progress={ caption="Dialog box needs attention..." }, main=function( call )

        self:_initOp( call )

        if not self.filenamePreset then
            app:show{ warning="Requisite filenameing preset not found - try restarting Lightroom." }
            call:cancel()
            return
        end
    
        local photos = catalog:getTargetPhotos()
        if #photos == 0 then
            app:show{ warning="No photos in filmstrip - the same photos must be selected as were selected when you invoked 'Rename Files - Start'." }
            call:cancel()
            return
        end
        
        if self.photos == nil then        
            app:show{ warning="You must invoke 'Rename Files - Start' before invoking 'Rename Files - Finish'" }
            call:cancel()
            return
        end
        
        if #self.photos ~= #photos then        
            app:show{ warning="Uh-oh - the same photos must be selected as were selected when you invoked 'Rename Files - Start'." }
            call:cancel()
            return
        end
        
        local presetName = app.prefMgr:getPresetName() -- current preset name.
        --local props = LrBinding.makePropertyTable( call.context )

        local vi = {}
        local ttl
        if call.testMode then
            ttl = "*** TEST MODE ONLY: NO CHANGES WILL BE MADE TO YOUR CATALOG OR PHOTO FILES (EXCEPT RENAME COLLECTION)."
        else
            ttl = "*** REAL MODE: CHANGES MAY BE MADE TO YOUR CATALOG, AS INDICATED IN LOG FILE UPON COMPLETION."
        end
        vi[#vi + 1] = 
            vf:static_text {
                title = ttl,
                fill_horizontal = 1,
            }

        local answer = app:show{ confirm="Finish rename ^1 according to ^2?",
            subs = { str:nItems( #photos, "photos" ), presetName },
            viewItems = vi,
        }
        if answer ~= 'ok' then
            call:cancel()
            return
        end

        local s, m = self:_initRun( call, photos ) -- no props
        if s then
            -- ok - details already logged.
        else
            app:logErr( m )
            return
        end

        local s, m = self:_renameFinish( call )        
        if s then
            -- enough logged already.
        else
            app:logErr( "There has been an error: ^1 - your catalog was not altered.", m )
            app:show{ error="There has been an error: ^1 - your catalog was not altered.", m }
        end
        
        
    end, finale=function( call )
        self:_wrapOp( call )
    end } )
    
end



return Renamer
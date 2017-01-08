--[[
        Binding.lua
--]]

local Binding, dbg, dbgf = Object:newClass{ className = 'Binding' }



--- Constructor for extending class.
--
function Binding:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Binding:new( t )
    local o = Object.new( self, t )
    return o
end



--- Define binding which asserts (true) if all criteria match.
--
--  @usage all keys must be from same property table, which must be passed.
--
--  @param params
--      <br>    props (property-table, required) bind-to object.
--      <br>    trueKeys (array, optional) of those having to be true
--      <br>    unTrueKeys (array, optional) of those having to be false or nil.
--      <br>    valueTable (table, optional) keys are keys and values are values which must match for truth.
--      <br>    unValueTable (table, optional) keys are keys and values are values which must NOT match for truth.
--      <br>    matchValue (any, default: true) value to return upon match.
--      <br>    unMatchValue (any, default: false) value to return if not matching.
--
--  @return binding assignable to enabled/visible or value... (make sure match/un-match values are compatible with target assignment type).
--
function Binding:getMatchBinding( params )
    local props = params.props or app:callingError( "need props (bind-to-object)" )
    local keys
    if params.trueKeys and params.unTrueKeys then
        keys = tab:mergeArrays( params.trueKeys, params.unTrueKeys )
    elseif params.trueKeys then
        if params.valueTable then
            keys = tab:copy( params.trueKeys )
        else
            keys = params.trueKeys
        end
    elseif params.unTrueKeys then
        if params.valueTable then
            keys = tab:copy( params.unTrueKeys )
        else
            keys = params.unTrueKeys
        end
    end
    if params.valueTable then
        if keys == nil then
            keys = {}
        end
        for k in pairs( params.valueTable ) do
            keys[#keys + 1] = k
        end
    end
    if params.unValueTable then
        if keys == nil then
            keys = {}
        end
        for k in pairs( params.unValueTable ) do
            keys[#keys + 1] = k
        end
    elseif keys == nil then
        app:callingError( "no keys" )
    end
    local unMatchValue = params.unMatchValue
    if unMatchValue == nil then
        unMatchValue = false
    end
    local matchValue = params.matchValue
    if matchValue == nil then
        matchValue = true
    end
    return LrView.bind {
        keys = keys,
        bind_to_object = props,
        operation = function()
            if params.trueKeys then
                for i, key in ipairs( params.trueKeys ) do
                    if not props[key] then return unMatchValue end
                end
            end
            if params.unTrueKeys then
                for i, key in ipairs( params.unTrueKeys ) do
                    if props[key] then return unMatchValue end
                end
            end
            if params.valueTable then
                for key, value in pairs( params.valueTable ) do
                    if value ~= props[key] then return unMatchValue end
                end
            end
            if params.unValueTable then
                for key, value in pairs( params.unValueTable ) do
                    if value == props[key] then return unMatchValue end
                end
            end
            return matchValue
        end
    }
end



--[[
function Binding:getUniPrefBinding( keys, implFunc )
    return LrView.bind {
        bind_to_object = prefs,
        keys = keys,
        operation = function()
        
        end
    }
end
--]]


function Binding:bind( to, t )
    if type( t ) == 'table' then
        t.bind_to_object = to
        return LrView.bind( t )
    else
        return LrView.bind {
            key=t,
            bind_to_object=to
        }
    end
end


return Binding

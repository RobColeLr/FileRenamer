--[[
        Metadata.lua
        
        Note: Metadata module must be edited to taste after plugin generator copies to destination.
--]]

local metadataTable = {} -- return table
local photoMetadata = {} -- photo metadata definition table

--[[
        Uncomment/add metadata here:
        
        id - used by plugin code only.
        title => add to library panel with this name/label (pre-requisite for searchable)
        
        dataType - string or enum are the only things that make sense @LR3.3.
            Hopefully Adobe will add boolean, number, and date soon.
            Recommendation: always set this to string if not enum type, if browsable.
            Reason: although you can store any data type in datatype-unspecified field,
                    smart collections will appear broken if any non-string values are written,
                    so might as well impose this on yourself/your-plugin.
            
        browsable => usable in metadata column of library filter.
        searchable => usable in smart collections.
        
        version - only need to bump this if Lightroom isn't taking your changes, OR you want to use it in the update function.
        
        *** IMPORTANT NOTE: If you've left the dataType off for non-enum types (presumably by mistake, in the past), then still:
        Always convert browsable data (except enum) to string before writing, else smart collections will appear broken to the user.            
--]]
         
photoMetadata[#photoMetadata + 1] = { id='temp_', version=1, dataType='string', title="Temp" } -- for temp storage of headline field.
-- Where to put previous filename. Personally, I'd like to use it as title, if it was title-ish before.

--[[
        Update metadata from previous schema to new schema, if need be.
        
        No sense of having this until if/when schema version is bumped...
--]]        
-- local function updateFunc( catalog, previousSchemaVersion )
-- end

metadataTable.metadataFieldsForPhotos = photoMetadata
metadataTable.schemaVersion = 1
-- metadataTable.updateFromEarlierSchemaVersion = updateFunc

return metadataTable
    


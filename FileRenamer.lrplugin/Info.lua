--[[
        Info.lua
--]]

return {
    appName = "File Renamer",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.FileRenamer",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc File Renamer",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/FileRenamerLrPlugin",
    LrPluginInfoProvider = "ExtendedManager.lua",
    LrToolkitIdentifier = "com.robcole.FileRenamer",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    LrMetadataProvider = "Metadata.lua",
    LrMetadataTagsetFactory = "Tagsets.lua",
    LrLibraryMenuItems = {
        {
            title = "&Rename Files - Start",
            file = "mRenameFilesStart.lua",
        },
        {
            title = "&Rename Files - Finish",
            file = "mRenameFilesFinish.lua",
        },
    },
    LrHelpMenuItems = {
        {
            title = "General Help",
            file = "mHelp.lua",
        },
    },
    VERSION = { display = "1.14.1    Build: 2014-12-07 02:36:47" },
}

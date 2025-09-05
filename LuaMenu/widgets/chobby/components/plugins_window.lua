---@diagnostic disable: undefined-global
-- WG is a global injected by the Chobby environment
PluginsWindow = LCS.class {}

PluginsWindow.LEFT_MARGIN = 20
PluginsWindow.TOP_MARGIN = 17
PluginsWindow.RIGHT_MARGIN = 20
PluginsWindow.BOTTOM_MARGIN = 0

local lastFilter = ""
local pluginsList = {}  -- stores plugin data (tables with name, id, etc.)
local pluginPanels = {} -- maps plugin.id to panel
local grid = nil

-- Remote plugin manifest resource
local plugin_manifest = {
    name = "plugin_manifest",
    url = "https://bar-workshop.zen-ben.com/bar-workshop/manifests.json",
    destination = "LuaUI/Widgets/manifests.json", -- it's placed in the widgets folder so the game will create it for us
    content = nil,
    parsed_contents = nil,
}

-- Image paths
local IMG_MISSING = LUA_DIRNAME .. "../../images/load_img_32.png" -- TODO: this is not working

-- Returns the local image path for a plugin
local function getPluginImagePath(plugin)
    local widget_name = plugin.id or plugin.name or "unknown"
    return "plugins/" .. widget_name .. "_325x100.png"
end

-- Triggers download of the plugin image if not present
local function ensurePluginImageDownloaded(plugin)
    Spring.Echo("[PluginsWindow] Ensuring image for plugin:", plugin.name or "unknown")
    local widget_name = plugin.id or plugin.name or "unknown"
    local localPath = getPluginImagePath(plugin)

    -- Check if file exists, otherwise use a fallback and trigger download
    if not VFS.FileExists(localPath) then
        local url = "https://bar-workshop.zen-ben.com/bar-workshop/sites/" ..
            widget_name .. "/" .. widget_name .. "_325x100.png"
        Spring.Echo("[PluginsWindow] Downloading image for plugin:", widget_name, "from", url)
        -- Extract directory from localPath and create it if needed

        local dir = string.match(localPath, "^(.+)/[^/]+$")
        if dir then Spring.CreateDir(dir) end
        if WG.DownloadHandler and WG.DownloadHandler.MaybeDownloadArchive then
            WG.DownloadHandler.MaybeDownloadArchive(widget_name .. "_image", "resource", -1, {
                url = url,
                destination = localPath,
                extract = false,
            })
        end
        return IMG_MISSING -- Return fallback while downloading
    end

    return localPath
end

local function getPluginCoverImagePath(plugin)
    local widget_name = plugin.id or plugin.name or "unknown"
    return "plugins/" .. widget_name .. "_460x300.png"
end

local function ensurePluginCoverImageDownloaded(plugin)
    Spring.Echo("[PluginsWindow] Ensuring cover image for plugin:", plugin.name or "unknown")
    local widget_name = plugin.id or plugin.name or "unknown"
    local localPath = getPluginCoverImagePath(plugin)

    -- Check if file exists, otherwise use a fallback and trigger download
    if not VFS.FileExists(localPath) then
        local url = "https://bar-workshop.zen-ben.com/bar-workshop/sites/" ..
            widget_name .. "/" .. widget_name .. "_460x300.png"
        Spring.Echo("[PluginsWindow] Downloading cover image for plugin:", widget_name, "from", url)
        -- Extract directory from localPath and create it if needed

        local dir = string.match(localPath, "^(.+)/[^/]+$")
        if dir then Spring.CreateDir(dir) end
        if WG.DownloadHandler and WG.DownloadHandler.MaybeDownloadArchive then
            WG.DownloadHandler.MaybeDownloadArchive(widget_name .. "_cover_image", "resource", -1, {
                url = url,
                destination = localPath,
                extract = false,
            })
        end
        return IMG_MISSING -- Return fallback while downloading
    end

    return localPath
end

local function getPluginReadmePath(plugin)
    local widget_name = plugin.id or plugin.name or "unknown"
    return "plugins/" .. widget_name .. "_README.md"
end

local function ensurePluginReadmeDownloaded(plugin)
    Spring.Echo("[PluginsWindow] Ensuring README for plugin:", plugin.name or "unknown")
    local widget_name = plugin.id or plugin.name or "unknown"
    local localPath = getPluginReadmePath(plugin)

    -- Check if file exists, otherwise trigger download
    if not VFS.FileExists(localPath) then
        local url = "https://bar-workshop.zen-ben.com/bar-workshop/sites/" ..
            widget_name .. "/" .. widget_name .. ".md"
        Spring.Echo("[PluginsWindow] Downloading README for plugin:", widget_name, "from", url)
        -- Extract directory from localPath and create it if needed

        local dir = string.match(localPath, "^(.+)/[^/]+$")
        if dir then Spring.CreateDir(dir) end
        if WG.DownloadHandler and WG.DownloadHandler.MaybeDownloadArchive then
            WG.DownloadHandler.MaybeDownloadArchive(widget_name .. "_readme", "resource", -1, {
                url = url,
                destination = localPath,
                extract = false,
                pluginId = plugin.id,
            })
        end
    end

    return localPath
end

local function ClosePluginDetailWindow()
    Spring.Echo("[PluginsWindow] ClosePluginDetailWindow called")
    if pluginDetailWindow then
        Spring.Echo("[PluginsWindow] Disposing pluginDetailWindow")
        pluginDetailWindow:Dispose()
        pluginDetailWindow = nil
    else
        Spring.Echo("[PluginsWindow] pluginDetailWindow is nil")
    end
end

local function getPluginPanel(plugin, itemWidth)
    local imagePath = ensurePluginImageDownloaded(plugin);

    local panel = Panel:New {
        children = {
            Label:New {
                caption = plugin.name or "Plugin Name",
                x = 10,
                y = 105,
                width = itemWidth - 20,
                height = 60,
                fontSize = 18,
                autosize = false,
                wordwrap = true,
            },
            Label:New {
                caption = "by " .. (plugin.author or "Author Name"),
                x = 10,
                y = 165,
                width = itemWidth - 20,
                fontSize = 11,
                autosize = false,
                wordwrap = true,
            },
            Label:New {
                caption = plugin.description or "Description of the plugin goes here. This is a placeholder text.",
                x = 10,
                y = 170,
                width = itemWidth - 20,
                height = 60,
                fontSize = 14,
                autosize = false,
                wordwrap = true,
            },
            Button:New {
                caption = "Download",
                right = 85,
                bottom = 5,
                height = 30,
                OnClick = 
                {
                    function()
                        Spring.Echo("[PluginsWindow] Download button clicked for plugin:", plugin.name);
                        -- open the browser straight to the zip file
                        local zipFileUrl = "https://bar-workshop.zen-ben.com/bar-workshop/distributions/" ..
                            (plugin.id or plugin.name) .. ".zip";
                        Spring.Echo("[PluginsWindow] Opening browser to:", zipFileUrl);
                        WG.WrapperLoopback.OpenUrl(zipFileUrl);
                    end
                },
            },
            Button:New {
                caption = "Details",
                right = 5,
                bottom = 5,
                height = 30,
                OnClick = 
                -- {
                --     function()
                --         Spring.Echo("[PluginsWindow] Download button clicked for plugin:", plugin.name);
                --         -- open the browser straight to the zip file
                --         local zipFileUrl = "https://bar-workshop.zen-ben.com/bar-workshop/distributions/" ..
                --             (plugin.id or plugin.name) .. ".zip";
                --         Spring.Echo("[PluginsWindow] Opening browser to:", zipFileUrl);
                --         WG.WrapperLoopback.OpenUrl(zipFileUrl);
                --     end
                -- }
                {
                    function()
                        Spring.Echo("[PluginsWindow] Plugin panel clicked for plugin:", plugin.name);
                        -- Download the plugins assets, we need cover.png, README.MD
                        local coverImagePath = ensurePluginCoverImageDownloaded(plugin);
                        local readmePath = ensurePluginReadmeDownloaded(plugin);

                        local pluginDetailWindow = Window:New {
                            x = "20%",
                            y = "20%",
                            width = "40%",
                            height = "60%",
                            parent = WG.Chobby.lobbyInterfaceHolder,
                            caption = plugin.name or "Plugin Details",
                            resizable = false,
                            draggable = false,
                            classname = "main_window",
                            children = {
                                -- Description on the left
                                ScrollPanel:New {
                                    x = 20,
                                    y = 20,
                                    width = "60%",
                                    height = "90%",
                                    children = {
                                        Label:New {
                                            caption = VFS.LoadFile(readmePath) or "README not available.",
                                            x = 0,
                                            y = 0,
                                            width = "100%",
                                            fontSize = 14,
                                            wordwrap = true,
                                        },
                                    },
                                },
                                -- Buttons on the top right
                                Button:New {
                                    right = 12,
                                    y = 7,
                                    width = 80,
                                    height = 45,
                                    caption = i18n("close"),
                                    objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
                                    classname = "negative_button",
                                    OnClick = { function() ClosePluginDetailWindow() end },
                                },
                                Button:New {
                                    caption = "Download",
                                    x = "65%",
                                    y = 70,
                                    width = 100,
                                    height = 40,
                                    OnClick = { function()
                                        local zipFileUrl = "https://bar-workshop.zen-ben.com/bar-workshop/distributions/" ..
                                            (plugin.id or plugin.name) .. ".zip"
                                        WG.WrapperLoopback.OpenUrl(zipFileUrl)
                                    end },
                                },
                                Button:New {
                                    caption = "Homepage",
                                    x = "65%",
                                    y = 120,
                                    width = 100,
                                    height = 40,
                                    OnClick = { function()
                                        if plugin.homepage then
                                            WG.WrapperLoopback.OpenUrl(plugin.homepage)
                                        else
                                            Spring.Echo("[PluginsWindow] No homepage URL available for plugin:", plugin.name)
                                        end
                                    end },
                                },
                                -- Cover image below the buttons
                                Image:New {
                                    file = coverImagePath,
                                    x = "65%",
                                    y = 180,
                                    width = "30%",
                                    height = "50%",
                                    keepAspect = true,
                                    checkFileExists = true,
                                    fallbackFile = IMG_MISSING,
                                },
                            }
                        };
                    end
                }
            },
            Image:New {
                file = imagePath, -- VFS-relative path, not LUA_DIRNAME
                x = 0,
                y = 0,
                width = itemWidth,
                height = 100,
                keepAspect = true,
                checkFileExists = true,
                fallbackFile = IMG_MISSING, -- Use the defined constant for consistency
            }
        }
    }

    -- Store plugin id in panel for later reference
    panel.pluginId = plugin.id

    return panel
end

local function getFilteredData()
    if lastFilter == "" then
        return pluginsList
    end
    local filtered = {}
    for _, plugin in ipairs(pluginsList) do
        if plugin.name and string.find(plugin.name:lower(), lastFilter:lower()) then
            table.insert(filtered, plugin)
        end
    end
    return filtered
end

local function DownloadFinished(listener, downloadID, downloadName, downloadFileType)
    Spring.Echo("[PluginsWindow] DownloadFinished:", downloadID, downloadName, downloadFileType)
    Spring.Echo("[PluginsWindow] DEBUG: Checking if this is manifest download")
    Spring.Echo("[PluginsWindow] DEBUG: downloadName:", tostring(downloadName))
    Spring.Echo("[PluginsWindow] DEBUG: plugin_manifest.name:", tostring(plugin_manifest.name))
    Spring.Echo("[PluginsWindow] DEBUG: Names match:", downloadName == plugin_manifest.name)

    -- Handle manifest download as before
    if downloadName == plugin_manifest.name then
        Spring.Echo("[PluginsWindow] DEBUG: Processing manifest download for:", downloadName)
        Spring.Echo("[PluginsWindow] DEBUG: Attempting to open file:", plugin_manifest.destination)

        local f = io.open(plugin_manifest.destination, "r")
        if f then
            Spring.Echo("[PluginsWindow] DEBUG: File opened successfully")
            plugin_manifest.content = f:read("*all")
            f:close()

            -- DEBUG: Log raw manifest content
            Spring.Echo("[PluginsWindow] DEBUG: Raw manifest content length:", string.len(plugin_manifest.content))
            Spring.Echo("[PluginsWindow] DEBUG: Raw manifest content preview (first 500 chars):")
            Spring.Echo(string.sub(plugin_manifest.content, 1, 500))

            local ok, data = pcall(function() return Spring.Utilities.json.decode(plugin_manifest.content) end)
            if ok and type(data) == "table" then
                plugin_manifest.parsed_contents = data

                -- DEBUG: Log parsed manifest structure
                Spring.Echo("[PluginsWindow] DEBUG: Successfully parsed manifest JSON")
                Spring.Echo("[PluginsWindow] DEBUG: Manifest contains", #data, "plugins")
                Spring.Echo("[PluginsWindow] DEBUG: Manifest data type:", type(data))

                -- Populate pluginsList with manifest data
                pluginsList = {}
                for i, plugin in ipairs(data) do
                    -- DEBUG: Log each plugin being processed
                    Spring.Echo("[PluginsWindow] DEBUG: Processing plugin", i, ":")
                    Spring.Echo("  - id:", plugin.id or "nil")
                    Spring.Echo("  - display_name:", plugin.display_name or "nil")
                    Spring.Echo("  - name:", plugin.name or "nil")
                    Spring.Echo("  - author:", plugin.author or "nil")
                    Spring.Echo("  - description:",
                        plugin.description and string.sub(plugin.description, 1, 100) or "nil")

                    -- Map display_name to name
                    if plugin.display_name then
                        plugin.name = plugin.display_name
                        Spring.Echo("  - mapped display_name to name:", plugin.name)
                    end
                    pluginsList[#pluginsList + 1] = plugin
                end

                -- DEBUG: Log final pluginsList state
                Spring.Echo("[PluginsWindow] DEBUG: Final pluginsList contains", #pluginsList, "plugins")
                -- Optionally, refresh the UI if grid exists
                if grid then
                    grid:ClearChildren()
                    local filteredData = getFilteredData()
                    local count = #filteredData
                    local columns = 4
                    local itemHeight = 300
                    local itemWidth = grid.itemWidth or 325 -- fallback if not set
                    local rows = math.ceil(count / columns)
                    for _, plugin in ipairs(filteredData) do
                        if plugin.id then
                            local panel = pluginPanels[plugin.id]
                            if not panel then
                                panel = getPluginPanel(plugin, itemWidth)
                                pluginPanels[plugin.id] = panel
                            end
                            grid:AddChild(panel)
                        end
                    end
                    grid.rows = rows
                    grid.height = rows *
                    itemHeight                      -- TODO: something is off about this height calculation, seems to give an extra row
                    grid:UpdateLayout()
                end
            else
                Spring.Echo("[PluginsWindow] DEBUG: Failed to parse plugin manifest JSON")
                Spring.Echo("[PluginsWindow] DEBUG: Parse result - ok:", ok, "data type:", type(data))
                if not ok then
                    Spring.Echo("[PluginsWindow] DEBUG: JSON parse error:", tostring(data))
                end
                Spring.Echo("[PluginsWindow] DEBUG: Content that failed to parse:")
                Spring.Echo(plugin_manifest.content)
            end
        else
            Spring.Echo("[PluginsWindow] DEBUG: Failed to open downloaded manifest file")
            Spring.Echo("[PluginsWindow] DEBUG: File path:", plugin_manifest.destination)
            Spring.Echo("[PluginsWindow] DEBUG: File exists check:", VFS.FileExists(plugin_manifest.destination))
            -- Try to list the current directory to see what files are there
            local files = VFS.DirList(".", "*.json")
            Spring.Echo("[PluginsWindow] DEBUG: JSON files in current directory:", #files)
            for i, filename in ipairs(files) do
                Spring.Echo("[PluginsWindow] DEBUG: Found JSON file:", filename)
            end
        end
        return
    end
end

local function DownloadPluginManifest()
    -- Ensure the manifest is never cached by:
    -- 1. Removing any existing manifest file
    -- 2. Adding a timestamp parameter to the URL for cache-busting
    -- 3. Using QueueDownload directly to bypass MaybeDownloadArchive's caching logic
    Spring.Echo("[PluginsWindow] DEBUG: Initiating manifest download")
    Spring.Echo("[PluginsWindow] DEBUG: Manifest URL:", plugin_manifest.url)
    Spring.Echo("[PluginsWindow] DEBUG: Manifest destination:", plugin_manifest.destination)

    -- Remove existing manifest file to ensure fresh download (no caching)
    if VFS.FileExists(plugin_manifest.destination) then
        Spring.Echo("[PluginsWindow] DEBUG: Removing existing manifest file to force fresh download")
        os.remove(plugin_manifest.destination)
    end

    -- Add timestamp to URL to prevent caching
    local timestamp = os.time()
    local url_with_cache_bust = plugin_manifest.url .. "?t=" .. timestamp
    Spring.Echo("[PluginsWindow] DEBUG: Cache-busted URL:", url_with_cache_bust)

    if WG.DownloadHandler and WG.DownloadHandler.QueueDownload then
        Spring.Echo("[PluginsWindow] DEBUG: DownloadHandler available, starting download")
        -- Use QueueDownload directly to bypass the MaybeDownloadArchive cache check
        WG.DownloadHandler.QueueDownload(plugin_manifest.name, "resource", -1, 0, {
            url = url_with_cache_bust,
            destination = plugin_manifest.destination,
            extract = false,
        })
    else
        Spring.Echo("[PluginsWindow] DEBUG: ERROR - DownloadHandler not available!")
        Spring.Echo("[PluginsWindow] DEBUG: WG.DownloadHandler exists:", WG.DownloadHandler ~= nil)
        if WG.DownloadHandler then
            Spring.Echo("[PluginsWindow] DEBUG: QueueDownload method exists:", WG.DownloadHandler.QueueDownload ~= nil)
        end
    end
end

function PluginsWindow:init(parent)
    -- Register download finished listener
    if WG.DownloadHandler and WG.DownloadHandler.AddListener then
        Spring.Echo("[PluginsWindow] DEBUG: Registering download finished listener")
        WG.DownloadHandler.AddListener("DownloadFinished", DownloadFinished)
    else
        Spring.Echo("[PluginsWindow] DEBUG: WARNING - Cannot register download listener")
        Spring.Echo("[PluginsWindow] DEBUG: WG.DownloadHandler exists:", WG.DownloadHandler ~= nil)
        if WG.DownloadHandler then
            Spring.Echo("[PluginsWindow] DEBUG: AddListener method exists:", WG.DownloadHandler.AddListener ~= nil)
        end
    end

    -- Start download of plugin manifest
    Spring.Echo("[PluginsWindow] DEBUG: Starting manifest download")
    DownloadPluginManifest()

    local widthAvailable = 1300
    local columns = 4
    local itemWidth = widthAvailable / columns
    local itemHeight = 300

    self.window = Window:New {
        x = 0,
        right = 0,
        y = 0,
        bottom = 0,
        padding = { PluginsWindow.LEFT_MARGIN, PluginsWindow.TOP_MARGIN, PluginsWindow.RIGHT_MARGIN, PluginsWindow.BOTTOM_MARGIN },
        parent = parent,
        resizable = false,
        draggable = false,
        classname = "PluginsWindow",
    }

    -- Top bar elements

    -- Plugins label
    Label:New {
        objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
        caption = "Plugins",
        x = 0,
        y = 0,
        width = 120,
        height = 50,
        valign = "center",
        parent = self.window,
    }
    -- Info label right after Plugins label
    Label:New {
        caption = "Plugins are provided by the community. The BAR-team is not responsible for the content or quality of the plugins found here.",
        x = 125,
        y = 0,
        width = 500,
        height = 50,
        autosize = false,
        valign = "center",
        fontSize = 14,
        parent = self.window,
    }
    -- Buttons after info label
    Button:New {
        caption = "Installation guide",
        x = 635,
        y = 10,
        width = 130,
        height = 30,
        OnClick = { function() WG.WrapperLoopback.OpenUrl("https://github.com") end },
        parent = self.window,
    }
    Button:New {
        caption = "Plugins Folder",
        x = 775,
        y = 10,
        width = 140,
        height = 30,
        OnClick = { function() WG.WrapperLoopback.OpenFolder(WG.Connector.writePath .. "/LuaUI/Widgets") end },
        parent = self.window,
    }
    Button:New {
        caption = "Contribute",
        x = 1000,
        y = 10,
        width = 100,
        height = 30,
        OnClick = { function() WG.WrapperLoopback.OpenUrl("https://github.com") end },
        parent = self.window,
    }
    -- Search box right-aligned
    EditBox:New {
        text = "",
        right = 0,
        y = 10,
        width = 150,
        height = 30,
        hint = "Search plugins...",
        OnKeyPress = { function(obj, key)
            local value = obj.text
            if value ~= lastFilter then
                lastFilter = value or ""
                if grid then
                    grid:ClearChildren()
                    local filteredData = getFilteredData()
                    local count = #filteredData
                    local columns = 4
                    local itemHeight = 300
                    local itemWidth = grid.itemWidth or 325
                    local rows = math.ceil(count / columns)
                    -- Always repopulate grid with all plugin panels if filter is empty
                    if lastFilter == "" then
                        for _, plugin in ipairs(pluginsList) do
                            if plugin.id then
                                local panel = pluginPanels[plugin.id]
                                if not panel then
                                    panel = getPluginPanel(plugin, itemWidth)
                                    pluginPanels[plugin.id] = panel
                                end
                                grid:AddChild(panel)
                            end
                        end
                    else
                        for _, plugin in ipairs(filteredData) do
                            if plugin.id then
                                local panel = pluginPanels[plugin.id]
                                if not panel then
                                    panel = getPluginPanel(plugin, itemWidth)
                                    pluginPanels[plugin.id] = panel
                                end
                                grid:AddChild(panel)
                            end
                        end
                    end
                    -- Update grid rows and height
                    grid.rows = rows
                    grid.height = rows * itemHeight
                    grid:UpdateLayout()
                end
            end
        end },
        parent = self.window,
    }

    -- Initially, grid is empty; will be populated after manifest download
    local rows = 1
    grid = Grid:New {
        rows = rows,
        columns = columns,
        itemWidth = itemWidth,
        itemHeight = itemHeight,
        width = "100%",
        height = (rows) * itemHeight,
        children = {}
    }
    ScrollPanel:New {
        width = "100%",
        height = "90%",
        y = 80,
        parent = self.window,
        horizontalScrollbar = false,
        children = { grid }
    }

    Spring.Echo("[PluginsWindow] DEBUG: Initializing PluginsWindow")
end

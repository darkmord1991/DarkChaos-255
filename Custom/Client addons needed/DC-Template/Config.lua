local _, NS = ...
NS.Config = {}

-- Default settings
NS.Config.Defaults = {
    Enable = true,
    Debug = false,
    Message = "Hello World"
}

-- Function to load/save settings (placeholder for SavedVariables)
function NS.Config:Load()
    -- Logic to merge SavedVariables with Defaults would go here
end

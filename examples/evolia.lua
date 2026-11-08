local Evolia = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"))()
local Window = Evolia:CreateWindow({
    name = "Evolia",
    subtitle = "Your space. Your rhythm.",
    toggleKey = "RightShift",
    theme = "light",
    diameter = 460,
    animationDuration = 0.65,
    visible = true,
})

local Home = Window:CreateTab({ name = "Home" })
local Controls = Window:CreateTab({ name = "Controls" })
local Colors = Window:CreateTab({ name = "Colors" })
local Insights = Window:CreateTab({ name = "Insights" })
local Layout = Window:CreateTab({ name = "Layout" })
local Tag = Window:CreateTag({ name = "PREVIEW", width = 82 })

Home:CreateText({ name = "Welcome home", content = "A quiet circle for your controls. Explore the tabs or make the whole interface your own in Appearance." })
Home:CreateButton({ name = "A small hello", buttonText = "Notify", callback = function()
    Window:Notify({ title = "Hello from Evolia", content = "Every element has a handle. Every detail is yours." })
end })
Home:CreateButton({ name = "Take a closer look", buttonText = "Open", callback = function()
    Window:Popup({
        title = "Made to feel calm",
        subtitle = "A circular workspace",
        boxes = {
            { title = "Your controls", description = "Create tabs, arrange groups, and connect callbacks." },
            { title = "Your style", description = "Change every theme color, spacing, typography, and motion." },
        },
        options = { { text = "Lovely", style = "primary" } },
    })
end })

local Log = Insights:CreateConsole({ name = "Activity", text = "Evolia is ready.", height = 150, maxLines = 100, follow = true })
local Count = Insights:CreateStat({ name = "Changes", value = 0 })
local Progress = Insights:CreateProgress({ name = "Preview level", range = { 0, 100 }, value = 50, suffix = "%" })
Controls:CreateSection({ name = "Everyday controls" })
Controls:CreateToggle({ name = "Enabled", value = true, callback = function(value)
    Log:Append("Enabled: " .. tostring(value)); Count:Set(Count:Get() + 1)
end })
Controls:CreateSlider({ name = "Level", range = { 0, 100 }, value = 50, increment = 1, suffix = "%", callback = function(value)
    Progress:Set(value)
end })
Controls:CreateDropdown({ name = "Profile", options = { "Soft", "Balanced", "Crisp" }, value = "Soft", callback = function(value)
    Log:Append("Profile: " .. tostring(value))
end })
Controls:CreateDropdown({ name = "Visible tools", options = { "Status", "History", "Notes" }, multiSelect = true, value = { "Status" } })
Controls:CreateInput({ name = "Your label", placeholder = "Give this space a name", callback = function(value)
    Tag:Set(value ~= "" and value or "PREVIEW")
end })
Controls:CreateKeybind({ name = "Say hello", value = "T", mode = "press", callback = function()
    Window:Toast({ title = "Hello again", subtitle = "Your shortcut is working." })
end })
Colors:CreateParagraph({ name = "A palette that feels like you", content = "Choose a hue, drag inside the color map, type a hex value, or adjust alpha." })
Colors:CreateColorPicker({ name = "Accent", color = Window:GetTheme().accent, alpha = 1, callback = function(color, alpha)
    local theme = Window:GetTheme()
    theme.accent = theme.background:Lerp(color, alpha)
    Window:ChangeTheme(theme)
end })
Layout:CreateLabel({ text = "Small details, thoughtfully arranged." })
Layout:CreateDivider({ name = "Together" })
local Row = Layout:CreateGroup({ direction = "row" })
Row:CreateButton({ name = "One", buttonText = "Tap", callback = function() Window:Toast({ title = "One" }) end })
Row:CreateButton({ name = "Two", buttonText = "Tap", callback = function() Window:Toast({ title = "Two" }) end })
Layout:CreateText({ name = "Room to grow", content = "Nest row and column groups, reorder elements, and keep the center uncluttered." })
Window:CreateSettingsTab({ name = "Appearance" })

import "ui/discover"
local graphics <const> = playdate.graphics
local ui <const> = playdate.ui

UI = {}

local scenes <const> = {
    DISCOVER = Discover,
    -- FEED = "FEED",
    -- LIBRARY = "LIBRARY",
    -- EPISODES = "EPISODES",
    -- PLAY = "PLAY",
    -- SETTINGS = "SETTINGS",
}

local currentScene = scenes.DISCOVER
local nextScene = nil

function UI.update()
    assert(currentScene, "No current scene set")
    currentScene.update()
    if nextScene then
        --TODO: add transition logic here
        currentScene = nextScene
        nextScene = nil
    end
end

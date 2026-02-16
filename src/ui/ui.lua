import "ui/discover"
import "ui/episodes"

local graphics <const> = playdate.graphics
local ui <const> = playdate.ui

UI = {}

local scenes <const> = {
    DISCOVER = Discover,
    -- FEED = "FEED",
    -- LIBRARY = "LIBRARY",
    EPISODES = Episodes,
    -- PLAY = "PLAY",
    -- SETTINGS = "SETTINGS",
}

local currentScene = scenes.DISCOVER
local nextScene = nil

local function switchScene(scene, args)
    assert(scenes[scene], "Scene " .. scene .. " does not exist")
    nextScene = scenes[scene]
    nextScene.init(args)
end

Discover.switchScene = switchScene
Episodes.switchScene = switchScene

function UI.update()
    assert(currentScene, "No current scene set")
    currentScene.update()
    if nextScene then
        --TODO: add transition logic here
        currentScene = nextScene
        nextScene = nil
    end
end

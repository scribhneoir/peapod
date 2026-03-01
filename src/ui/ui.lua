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

local currentScene = scenes.EPISODES
currentScene.init({
    id = "1415546090",
    title = "Into the Aether",
    subtitle = "A lowkey videogame podcast",
    feedUrl =
    "https://feeds.transistor.fm/intotheaether"
})
local nextScene = nil

local function switchScene(scene, args)
    assert(scenes[scene], "Scene " .. scene .. " does not exist")
    nextScene = scenes[scene]
    if nextScene.init then
        nextScene.init(args)
    end
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

function playdate.upButtonUp()
    if currentScene.upButtonUp then
        currentScene.upButtonUp()
    end
end

function playdate.downButtonUp()
    if currentScene.downButtonUp then
        currentScene.downButtonUp()
    end
end

function playdate.AButtonUp()
    if currentScene.AButtonUp then
        currentScene.AButtonUp()
    end
end

function playdate.BButtonUp()
    if currentScene.BButtonUp then
        currentScene.BButtonUp()
    end
end

function playdate.cranked(change, acceleratedChange)
    if currentScene.cranked then
        currentScene.cranked(change, acceleratedChange)
    end
end

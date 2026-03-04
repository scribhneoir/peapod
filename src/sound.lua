local player <const> = playdate.sound.sampleplayer
Sound = {}

local fx <const> = {
    click = player.new("assets/sound/click")
}

function Sound.play(effect)
    local p = fx[effect]
    if not p then return end
    if p:isPlaying() then return end
    p:play()
end

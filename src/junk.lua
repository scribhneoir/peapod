import "CoreLibs/utilities/where"
import "CoreLibs/object"
import "CoreLibs/timer"

local net <const> = playdate.network
local sound <const> = playdate.sound
-- https://redirect-stripper.scribhneoir.workers.dev
playdate.display.setRefreshRate(50)

print("Imports completed, network available: " .. tostring(net ~= nil))

-- File player for audio playback
local fileplayer = sound.fileplayer.new()
local targetFilename = "GLT2636346160.mp3"

local file = nil
local totalBytes = 0
local lastLoggedBytes = 0
local logInterval = 50000          -- Log every 50KB
local streamingThreshold = 1000000 -- Start playing after 1MB downloaded (even more buffer)
local hasStartedPlaying = false
local downloadComplete = false
local actualLengthDetected = false

local function fetchAudioViaProxy(originalUrl, filename)
    filename = filename or "audio.mp3"

    -- Use localhost proxy server on port 8000
    local proxyHost = "localhost"
    local proxyPort = 8000
    local proxyPath = "/proxy?url=" .. originalUrl

    print("Fetching via proxy: " .. originalUrl)
    print("Proxy URL: http://" .. proxyHost .. ":" .. proxyPort .. proxyPath)

    local conn = net.http.new(proxyHost, proxyPort, false) -- HTTP, not HTTPS for localhost
    if not conn then
        print("Error: Could not create proxy connection")
        return
    end

    conn:setConnectTimeout(10)
    conn:setReadTimeout(60) -- Longer timeout for proxy downloads

    -- Reset state
    totalBytes = 0
    lastLoggedBytes = 0
    hasStartedPlaying = false
    if file then
        file:close()
        file = nil
    end

    local callbackCount = 0

    conn:setHeadersReadCallback(function()
        local statusCode, headers = conn:getResponseHeaders()
        print("Proxy response headers received")

        if type(statusCode) == "table" then
            print("Headers from proxy:")
            for k, v in pairs(statusCode) do
                print("  " .. tostring(k) .. ": " .. tostring(v))
            end
        else
            print("Proxy status: " .. tostring(statusCode))
            if headers then
                print("Proxy headers:")
                for k, v in pairs(headers) do
                    print("  " .. k .. ": " .. v)
                end
            end
        end
    end)

    conn:setRequestCallback(function()
        callbackCount = callbackCount + 1
        print("Proxy data callback (call #" .. callbackCount .. ")")

        local bytes = conn:getBytesAvailable()
        print("Bytes available from proxy: " .. bytes)

        if bytes > 0 then
            local chunk = conn:read(bytes)
            if chunk then
                print("Read chunk from proxy: " .. #chunk .. " bytes")

                if not file then
                    file = playdate.file.open(filename, playdate.file.kFileWrite)
                    if not file then
                        print("Error: Could not open file for writing: " .. filename)
                        return
                    end
                    print("Opened file for writing: " .. filename)
                end

                file:write(chunk)
                totalBytes = totalBytes + #chunk

                if totalBytes - lastLoggedBytes >= logInterval then
                    print("Downloaded via proxy: " .. math.floor(totalBytes / 1024) .. " KB")
                    lastLoggedBytes = totalBytes
                end

                -- Try to start streaming playback once we have enough data
                if not hasStartedPlaying and totalBytes >= streamingThreshold then
                    hasStartedPlaying = true
                    print("🎵 Starting playback with " .. math.floor(totalBytes / 1024) .. " KB buffered...")

                    -- Don't interrupt download - start a timer to try playback
                    playdate.timer.new(1000, function()
                        -- Try to load and play without closing the download file
                        local tempPlayer = sound.fileplayer.new()
                        local success, error = tempPlayer:load(filename)
                        if success then
                            print("Successfully loaded " .. filename .. " for playback")

                            tempPlayer:setFinishCallback(function(player)
                                print("Playback finished!")
                            end)

                            -- Monitor for unexpected stops during streaming
                            local function monitorPlayback()
                                if not downloadComplete and tempPlayer:isPlaying() then
                                    local currentPos = tempPlayer:getOffset()
                                    local fileLength = tempPlayer:getLength()

                                    -- If we're near the end of what was cached and download is still going
                                    if currentPos >= fileLength - 5 and not downloadComplete then
                                        print("Near cached end at " ..
                                        string.format("%.1f", currentPos) .. "s, waiting for more data...")
                                    end

                                    -- Schedule next check
                                    playdate.timer.new(2000, monitorPlayback)
                                elseif not downloadComplete and not tempPlayer:isPlaying() then
                                    print("⚠️ Playback stopped unexpectedly during streaming at " ..
                                    string.format("%.1f", tempPlayer:getOffset()) .. "s")
                                end
                            end

                            -- Set a larger buffer size
                            tempPlayer:setBufferSize(3.0) -- 3 seconds buffer

                            local playResult = tempPlayer:play()
                            if playResult then
                                print("🎉 Started playback! File length detected: " ..
                                tempPlayer:getLength() .. " seconds")
                                print("Buffered " .. math.floor(totalBytes / 1024) .. " KB before starting")
                                -- Replace the global fileplayer with our playing one
                                fileplayer = tempPlayer

                                -- Start monitoring playback
                                playdate.timer.new(2000, monitorPlayback)
                            else
                                print("Failed to start playback")
                                hasStartedPlaying = false
                            end
                        else
                            print("Failed to load file for playback: " .. tostring(error))
                            hasStartedPlaying = false
                        end
                    end)
                end
            end
        end
    end)

    conn:setRequestCompleteCallback(function()
        print("Proxy request complete")
        print("Total proxy callbacks: " .. callbackCount)

        local err = conn:getError()
        print("Proxy error status: " .. tostring(err))

        if file then
            file:close()
            file = nil
            downloadComplete = true
            print("Proxy download complete: " .. filename .. " (" .. math.floor(totalBytes / 1024) .. " KB)")

            -- If we're currently playing, DON'T restart - just let it continue playing
            if hasStartedPlaying and fileplayer and fileplayer:isPlaying() then
                print("Download complete, but continuing current playback without interruption")
                print("Current position: " ..
                string.format("%.1f", fileplayer:getOffset()) ..
                "s of " .. string.format("%.1f", fileplayer:getLength()) .. "s")

                -- Try to detect the actual file length now that download is complete
                playdate.timer.new(1000, function()
                    local testPlayer = sound.fileplayer.new()
                    local success, error = testPlayer:load(filename)
                    if success then
                        local actualLength = testPlayer:getLength()
                        print("🎵 Complete file length detected: " .. string.format("%.1f", actualLength) .. "s")

                        -- If the actual length is much longer, we might want to inform the user
                        if actualLength > fileplayer:getLength() * 2 then
                            print("📏 Note: Full file is much longer than initially detected!")
                        end
                    end
                end)

                -- Just update the finish callback to ensure it knows the file is complete
                fileplayer:setFinishCallback(function(player)
                    print("Playback finished! (Full file was available)")
                end)
            elseif not hasStartedPlaying then
                -- If we haven't started playing yet (small file), start now
                print("Starting playback of completed download...")
                local success, error = fileplayer:load(filename)
                if success then
                    fileplayer:setFinishCallback(function(player)
                        print("Playback finished!")
                    end)

                    local playResult = fileplayer:play()
                    if playResult then
                        print("Started playing completed file: " .. fileplayer:getLength() .. " seconds")
                        hasStartedPlaying = true
                    end
                end
            end
        else
            print("Proxy request complete but no file created")
        end
    end)

    -- Simple headers for proxy request
    local headers = {
        ["User-Agent"] = "Playdate/1.0",
        ["Accept"] = "audio/mpeg, audio/*, */*"
    }

    conn:query("GET", proxyPath, headers)
    print("Proxy request sent")
end

local function fetchAudioWithRedirects(url, filename, maxRedirects)
    maxRedirects = maxRedirects or 5
    filename = filename or "audio.mp3"

    local function doRequest(currentUrl, redirectCount)
        if redirectCount > maxRedirects then
            print("Error: Too many redirects")
            return
        end

        local host, port, secure, path = ParseURL(currentUrl)
        print("Attempt " .. redirectCount .. " - Fetching from: " .. host .. path)

        local conn = net.http.new(host, port, secure)
        if not conn then
            print("Error: Could not create connection")
            return
        end

        conn:setConnectTimeout(10)
        conn:setReadTimeout(30)

        -- Reset state on first request
        if redirectCount == 1 then
            totalBytes = 0
            lastLoggedBytes = 0
            if file then
                file:close()
                file = nil
            end
        end

        local callbackCount = 0
        local headersReceived = false

        -- Set headers read callback to check for redirects
        conn:setHeadersReadCallback(function()
            headersReceived = true
            local headers = conn:getResponseHeaders()
            local statusCode = conn:getResponseStatus()
            print("Headers received for attempt " .. redirectCount)
            print("Status code: " .. tostring(statusCode))

            -- The Playdate API seems to put headers in the statusCode parameter!
            local actualHeaders = nil
            local actualStatusCode = statusCode

            -- Print separate headers parameter if it exists
            if headers then
                print("Separate headers parameter:")
                for k, v in pairs(headers) do
                    print("  " .. tostring(k) .. ": " .. tostring(v))
                end
            end

            -- Look for redirects in the actual headers
            local foundRedirect = false
            if headers then
                for k, v in pairs(headers) do
                    if string.lower(tostring(k)) == "location" then
                        print("*** REDIRECT FOUND to: " .. tostring(v) .. " ***")
                        foundRedirect = true
                        -- Start a new request with the redirect URL
                        playdate.timer.new(100, function()
                            doRequest(tostring(v), redirectCount + 1)
                        end)
                        return
                    end
                end
            end

            if not foundRedirect then
                if actualStatusCode == 200 or (headers and not foundRedirect) then
                    print("Success! Starting download...")
                    if headers then
                        print("Response Headers:")
                        for k, v in pairs(headers) do
                            print("  " .. k .. ": " .. v)
                        end
                    end
                else
                    print("No redirect found and no valid response - request may have failed")
                end
            end
        end)

        conn:setRequestCallback(function()
            callbackCount = callbackCount + 1
            print("Data callback for attempt " .. redirectCount .. " (call #" .. callbackCount .. ")")

            local bytes = conn:getBytesAvailable()
            print("Bytes available: " .. bytes)

            if bytes > 0 then
                local chunk = conn:read(bytes)
                print("Read chunk: " .. (chunk and #chunk or "nil") .. " bytes")
                if chunk then
                    -- For binary data, write directly to file
                    if not file then
                        file = playdate.file.open(filename, playdate.file.kFileWrite)
                        if not file then
                            print("Error: Could not open file for writing: " .. filename)
                            return
                        end
                        print("Opened file for writing: " .. filename)
                        print("First chunk received: " .. #chunk .. " bytes")
                    end

                    file:write(chunk)
                    totalBytes = totalBytes + #chunk

                    -- Log progress periodically
                    if totalBytes - lastLoggedBytes >= logInterval then
                        print("Downloaded: " .. math.floor(totalBytes / 1024) .. " KB")
                        lastLoggedBytes = totalBytes
                    end

                    -- Try to start streaming playback once we have enough data (for direct downloads)
                    if not hasStartedPlaying and totalBytes >= streamingThreshold then
                        hasStartedPlaying = true
                        print("🎵 Starting playback with " .. math.floor(totalBytes / 1024) .. " KB buffered... (direct)")

                        -- Don't interrupt download - start a timer to try playback
                        playdate.timer.new(1000, function()
                            -- Try to load and play without closing the download file
                            local tempPlayer = sound.fileplayer.new()
                            local success, error = tempPlayer:load(filename)
                            if success then
                                print("Successfully loaded " .. filename .. " for playback (direct)")

                                tempPlayer:setFinishCallback(function(player)
                                    print("Playback finished!")
                                end)

                                -- Set a larger buffer size
                                tempPlayer:setBufferSize(3.0) -- 3 seconds buffer

                                local playResult = tempPlayer:play()
                                if playResult then
                                    print("🎉 Started direct playback! File length detected: " ..
                                    tempPlayer:getLength() .. " seconds")
                                    print("Buffered " .. math.floor(totalBytes / 1024) .. " KB before starting")
                                    -- Replace the global fileplayer with our playing one
                                    fileplayer = tempPlayer
                                else
                                    print("Failed to start direct playback")
                                    hasStartedPlaying = false
                                end
                            else
                                print("Failed to load file for direct playback: " .. tostring(error))
                                hasStartedPlaying = false
                            end
                        end)
                    end
                end
            end
        end)

        conn:setRequestCompleteCallback(function()
            print("Request complete for attempt " .. redirectCount)
            print("Total callbacks received: " .. callbackCount)
            print("Headers received: " .. tostring(headersReceived))

            local err = conn:getError()
            print("Error status: " .. tostring(err))
            if err and err ~= "Connection closed" then
                print("Error fetching URL: " .. err)
                return
            end

            if file then
                file:close()
                file = nil
                downloadComplete = true
                print("Download complete: " .. filename .. " (" .. math.floor(totalBytes / 1024) .. " KB)")

                -- If we're currently playing, DON'T restart - just let it continue playing
                if hasStartedPlaying and fileplayer and fileplayer:isPlaying() then
                    print("Download complete, but continuing current playbook without interruption")
                    print("Current position: " ..
                    string.format("%.1f", fileplayer:getOffset()) ..
                    "s of " .. string.format("%.1f", fileplayer:getLength()) .. "s")

                    -- Try to detect the actual file length now that download is complete
                    playdate.timer.new(1000, function()
                        local testPlayer = sound.fileplayer.new()
                        local success, error = testPlayer:load(filename)
                        if success then
                            local actualLength = testPlayer:getLength()
                            print("🎵 Complete file length detected: " .. string.format("%.1f", actualLength) .. "s")

                            -- If the actual length is much longer, we might want to inform the user
                            if actualLength > fileplayer:getLength() * 2 then
                                print("📏 Note: Full file is much longer than initially detected!")
                            end
                        end
                    end)

                    -- Just update the finish callback to ensure it knows the file is complete
                    fileplayer:setFinishCallback(function(player)
                        print("Playback finished! (Full file was available)")
                    end)
                elseif not hasStartedPlaying then
                    -- If we haven't started playing yet (small file), start now
                    print("Starting playback of completed download...")
                    local success, error = fileplayer:load(filename)
                    if success then
                        fileplayer:setFinishCallback(function(player)
                            print("Playback finished!")
                        end)

                        local playResult = fileplayer:play()
                        if playResult then
                            print("Started playing completed file: " .. fileplayer:getLength() .. " seconds")
                            hasStartedPlaying = true
                        end
                    end
                end
            else
                print("Request complete but no file was created")
            end
        end)

        -- Headers optimized for compatibility
        local headers = {
            ["User-Agent"] = "Mozilla/5.0 (compatible; Playdate/1.0)",
            ["Accept"] = "audio/mpeg, audio/*, */*",
            ["Connection"] = "close",      -- Force HTTP/1.1 behavior
            ["Cache-Control"] = "no-cache" -- Prevent caching issues
        }

        conn:query("GET", path, headers)
        print("Request sent for attempt " .. redirectCount)
    end

    -- Start the redirect chain
    doRequest(url, 1)
end

function ParseURL(url)
    local secure = string.match(url, "^https://") ~= nil
    local host = string.match(url, "^https?://([^/]+)")
    local path = string.match(url, "^https?://[^/]+(/.*)") or "/"
    local port = secure and 443 or 80
    return host, port, secure, path
end

-- Simple download and play function with proxy fallback
local function downloadAndPlay()
    print("=== Starting immediate streaming download and play ===")

    -- First try direct download
    print("Attempting direct download...")

    -- Reset global state for direct attempt
    downloadComplete = false
    hasStartedPlaying = false
    totalBytes = 0

    -- Try direct download first
    -- fetchAudioWithRedirects("https://dcs-spotify.megaphone.fm/GLT2636346160.mp3", targetFilename)
    fetchAudioWithRedirects(
    "https://dcs-spotify.megaphone.fm/GLT2636346160.mp3?key=508d9f4f6f600cdb91d0df532d39ac8e&request_event_id=2debfba8-c145-476d-bcf6-365ddb6ef333&session_id=8e0560f9-a391-4b35-8362-7b80a73aaded&timetoken=1770324756_A471F4E0768F87F6FE71D23A794EAB34",
        targetFilename)

    -- Check if direct download worked after 10 seconds
    playdate.timer.new(10000, function()
        if playdate.file.exists(targetFilename) and playdate.file.getSize(targetFilename) > 0 then
            print("✅ Direct download working! File size: " ..
            math.floor(playdate.file.getSize(targetFilename) / 1024) .. " KB")

            -- Start playing if we have enough data
            if not hasStartedPlaying then
                local fileSize = playdate.file.getSize(targetFilename)
                if fileSize >= streamingThreshold or downloadComplete then
                    print("Starting playback of direct download...")
                    hasStartedPlaying = true

                    local success, error = fileplayer:load(targetFilename)
                    if success then
                        fileplayer:setFinishCallback(function(player)
                            print("Playback finished!")
                        end)

                        local playResult = fileplayer:play()
                        if playResult then
                            print("🎉 Started playing direct download: " .. fileplayer:getLength() .. " seconds")
                        end
                    end
                end
            end
        else
            print("❌ Direct download failed or no data received")
            print("🔄 Falling back to proxy download...")

            -- Reset state for proxy attempt
            downloadComplete = false
            hasStartedPlaying = false
            totalBytes = 0

            -- Fall back to proxy download
            fetchAudioViaProxy("https://dcs-spotify.megaphone.fm/GLT2636346160.mp3", targetFilename)
        end
    end)

    -- Final fallback check after 30 seconds for very slow downloads
    playdate.timer.new(30000, function()
        if playdate.file.exists(targetFilename) and not hasStartedPlaying then
            print("Fallback: Starting playback after 30 second timeout...")
            local success, error = fileplayer:load(targetFilename)
            if success then
                fileplayer:setFinishCallback(function(player)
                    print("Playback finished!")
                end)

                local playResult = fileplayer:play()
                if playResult then
                    print("Fallback playback started: " .. fileplayer:getLength() .. " seconds")
                    hasStartedPlaying = true
                end
            end
        end
    end)
end

-- Start immediate download and play
downloadAndPlay()
local updateCount = 0

function playdate.update()
    -- Add immediate debug output
    if not updateCount then
        updateCount = 0
        print("=== UPDATE LOOP STARTED ===")
    end

    updateCount = updateCount + 1

    -- Print every 150 frames (about 3 seconds at 50fps)
    if updateCount % 150 == 0 then
        print("Update loop running, call #" .. updateCount .. ", time: " .. playdate.getCurrentTimeMilliseconds())

        -- Check if fileplayer is playing and show detailed status
        if fileplayer:isPlaying() then
            local offset = fileplayer:getOffset()
            local length = fileplayer:getLength()
            local actualLength = length

            -- If download is complete but file length seems too short, try to get updated length
            if downloadComplete and length < 600 and playdate.file.exists(targetFilename) and not actualLengthDetected then
                local fileSize = playdate.file.getSize(targetFilename)
                if fileSize > 10000000 then -- If file is bigger than 10MB, try to get proper length
                    local testPlayer = sound.fileplayer.new()
                    local success, error = testPlayer:load(targetFilename)
                    if success then
                        actualLength = testPlayer:getLength()
                        if actualLength > length then
                            print("🔄 Detected longer file length: " ..
                            string.format("%.1f", actualLength) .. "s (was " .. string.format("%.1f", length) .. "s)")
                            actualLengthDetected = true -- Prevent repeated detection
                        end
                    end
                end
            end

            local progress = (offset / actualLength) * 100
            print("🎵 Playing: " ..
            string.format("%.1f", offset) ..
            "s / " .. string.format("%.1f", actualLength) .. "s (" .. string.format("%.1f", progress) .. "%)")

            -- Show download status if still downloading
            if not downloadComplete then
                print("📥 Still downloading... " .. math.floor(totalBytes / 1024) .. " KB received")
            else
                local fileSize = playdate.file.getSize(targetFilename)
                print("📁 Complete file: " .. math.floor(fileSize / 1024) .. " KB")
            end
        elseif hasStartedPlaying and downloadComplete then
            -- If playback stopped but we know there's more content, try to restart with full file
            if playdate.file.exists(targetFilename) then
                local fileSize = playdate.file.getSize(targetFilename)
                if fileSize > 10000000 then
                    print("🔄 Playback stopped but full file available - restarting from current position...")

                    local newPlayer = sound.fileplayer.new()
                    local success, error = newPlayer:load(targetFilename)
                    if success then
                        print("📏 Full file length: " .. string.format("%.1f", newPlayer:getLength()) .. "s")

                        -- Try to resume from where we left off (get last position from stopped player)
                        local lastOffset = fileplayer:getOffset() or 0
                        newPlayer:setOffset(lastOffset)
                        newPlayer:setFinishCallback(function(player)
                            print("Full podcast playback finished!")
                        end)

                        local playResult = newPlayer:play()
                        if playResult then
                            print("▶️ Resumed playback from " .. string.format("%.1f", lastOffset) .. "s")
                            fileplayer = newPlayer
                            actualLengthDetected = true
                        else
                            print("Failed to resume playback")
                        end
                    end
                end
            end
        elseif hasStartedPlaying and not downloadComplete then
            print("⚠️ Audio should be playing but isn't - checking status...")
        end
    end

    -- Network callbacks are processed automatically during update
    playdate.timer.updateTimers()
end

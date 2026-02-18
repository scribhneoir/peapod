local net <const> = playdate.network

local function parseURL(url)
    local secure = string.match(url, "^https://") ~= nil
    local host = string.match(url, "^https?://([^/]+)")
    local path = string.match(url, "^https?://[^/]+(/.*)") or "/"
    local port = secure and 443 or 80
    return host, port, secure, path
end

local MAX_WORKERS = 2

local activeWorkers = {}

local worker = {}
-- TODO: handle retry logic for failed fetches
-- TODO: handle canceling fetches

function worker:handleHeaders()
    -- local headers = self.connection:getResponseHeaders()
    -- if headers then
    -- for key, value in pairs(headers) do
    --     print(key .. ": " .. value)
    -- end
    -- end
end

function worker:handleData()
    local bytes = self.connection:getBytesAvailable()
    if bytes > 0 then
        local chunk = self.connection:read(bytes)
        -- print("Received chunk of size:", #chunk)
        if chunk then
            self.file:download(chunk)
        end
    end
end

function worker:handleCallback()
    self.file:finishDownload()
    -- TODO: check file completeness
    if self.callback then
        self.callback(self.file)
    end
    -- print("Fetch complete for:", self.filepath)
    self.connection:close()
end

function worker:kill()
    -- print("Worker killed:", self.filepath)
    local index = nil
    for i, w in ipairs(activeWorkers) do
        if w == self then
            index = i
            break
        end
    end
    table.remove(activeWorkers, index)
    self = nil
end

function worker.new(url, callback, filepath)
    local self = setmetatable({}, { __index = worker })
    self.url = url
    self.callback = callback
    self.filepath = filepath

    local host, port, secure, path = parseURL(url)

    self.connection = net.http.new(host, port, secure)
    self.file = File.new(filepath)
    self.connection:setHeadersReadCallback(function() self:handleHeaders() end)
    self.connection:setRequestCallback(function() self:handleData() end)
    self.connection:setRequestCompleteCallback(function() self:handleCallback() end)
    self.connection:setConnectionClosedCallback(function() self:kill() end)
    local queued, err = self.connection:get(path,
        {
            ["User-Agent"] = "Mozilla/5.0 (Playdate)",
            ["Accept"] = "*/*",
            ["Connection"] = "close",      -- Force HTTP/1.1 behavior
            ["Cache-Control"] = "no-cache" -- Prevent caching issues
        }
    )
    return self
end

Network = {}
--todo: check if playdate.network.getStatus() == playdate.network.kStatusConnected. Otherwise, the app should run in offline mode.


local network_permission = false
local fetchQueue = {}

local function handleQueue()
    if #fetchQueue > 0 and #activeWorkers < MAX_WORKERS then
        local item = table.remove(fetchQueue, 1)
        -- print("Starting fetch for:", item.filepath)
        activeWorkers[#activeWorkers + 1] = worker.new(item.url, item.callback, item.filepath)
    end
    -- print("Active workers:", #activeWorkers, "Queue length:", #fetchQueue)
end

function Network.update()
    if not network_permission then
        network_permission = net.http.requestAccess(nil)
        if network_permission then
            -- print("Network access granted")
        else
            -- print("Network access denied")
        end
    else
        handleQueue()
    end
end

function Network.fetch(url, callback, filepath, priority)
    priority = priority or 1
    local index = #fetchQueue + 1
    for i, item in ipairs(fetchQueue) do
        if item.priority > priority then
            index = i
            break
        end
    end
    table.insert(fetchQueue, index, { url = url, callback = callback, filepath = filepath, priority = priority })
end

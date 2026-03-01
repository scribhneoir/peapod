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
    print("Received response headers for URL:", self.url)
    local headers = self.connection:getResponseHeaders()
    if headers and headers["Content-Length"] then
        print("Content-Length header found:", headers["Content-Length"])
        local num, err = tonumber(headers["Content-Length"])
        if not num then
            print("Error parsing content-length header " .. headers["Content-Length"] .. ":", err)
        else
            self.handler:setContentLength(num)
        end
    end
end

function worker:handleData()
    local bytes = self.connection:getBytesAvailable()
    if bytes > 0 then
        local chunk = self.connection:read(bytes)
        if chunk then
            self.handler:onData(chunk)
        end
    end
end

function worker:handleFinish()
    print("Finished receiving data for URL:", self.url)
    self.handler:onFinish()
    self.connection:close()
end

function worker:kill()
    print("Killing worker for URL:", self.url)
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

function worker.new(url, handler)
    print("Creating worker for URL:", url)
    local self = setmetatable({}, { __index = worker })
    self.url = url
    self.handler = handler

    local host, port, secure, path = parseURL(url)
    self.connection = net.http.new(host, port, secure)
    self.connection:setHeadersReadCallback(function() self:handleHeaders() end)
    self.connection:setRequestCallback(function() self:handleData() end)
    self.connection:setRequestCompleteCallback(function() self:handleFinish() end)
    self.connection:setConnectionClosedCallback(function() self:kill() end)
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Playdate)",
        ["Accept"] = "*/*",
    }
    local size = handler.getSize and handler:getSize() or 0
    if size > 0 then
        headers["Range"] = "bytes=" .. size .. "-"
    end
    local queued, err = self.connection:get(path, headers)
    if not queued then -- todo: implement retry logic for failed fetches
        print("Failed to queue request for:", url, "Error:", err)
        self:kill()
    end
    return self
end

Network = {}
--todo: check if playdate.network.getStatus() == CONNECTED. Otherwise, the app should run in offline mode.


local network_permission = false
local fetchQueue = {}

local function handleQueue()
    if #fetchQueue > 0 and #activeWorkers < MAX_WORKERS then
        local item = table.remove(fetchQueue, 1)
        activeWorkers[#activeWorkers + 1] = worker.new(item.url, item.handler)
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

function Network.fetch(url, handler, priority, redirect)
    priority = priority or 1
    local index = #fetchQueue + 1
    for i, item in ipairs(fetchQueue) do
        if item.priority > priority then
            index = i
            break
        end
    end
    if redirect and playdate.isSimulator then
        local redirectUrl = "https://redirect-stripper.scribhneoir.workers.dev/?url=" .. url
        local host, port, secure, path = parseURL(redirectUrl)
        local conn = net.http.new(host, port, secure)
        assert(conn, "Failed to create network connection for redirect stripping")
        conn:setRequestCompleteCallback(function()
            local bytes = conn:getBytesAvailable()
            if bytes > 0 then
                local chunk = conn:read(bytes)
                if chunk then
                    local data = json.decode(chunk)
                    for key, value in pairs(data) do
                        print(key)
                    end
                    if data and data.finalUrl then
                        table.insert(fetchQueue, index,
                            { url = data.finalUrl, handler = handler, priority = priority })
                    end
                end
            end
        end)
        conn:get(path)
    else
        table.insert(fetchQueue, index, { url = url, handler = handler, priority = priority })
    end
end

function Network.cancel(url)
    for _, w in ipairs(activeWorkers) do
        if w.url == url then
            print("Canceling active fetch for URL:", url)
            w.connection:close()
            return
        end
    end
    for i, item in ipairs(fetchQueue) do
        if item.url == url then
            print("Canceling queued fetch for URL:", url)
            table.remove(fetchQueue, i)
            return
        end
    end
end

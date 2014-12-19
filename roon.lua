local blog_name = nil
local url_count = 0
local tries = 0
local previous_status_code = nil


read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end


wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]

--  io.stdout:write("  ?" .. url .. " " .. tostring(verdict) .. ".  \n")
--  io.stdout:flush()

  if verdict and string.match(url, "%.roon%.io") and blog_name then
    -- Ensure we only grab the blog we are interested in
    if string.match(url, "//" .. blog_name .. "%.roon%.io") then
      return true
    else
      return false
    end
  end

  return verdict
end


wget.callbacks.httploop_result = function(url, err, http_stat)
  local status_code = http_stat["statcode"]

  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()
  
  previous_status_code = status_code

  if status_code == 0 or status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 5")

    tries = tries + 1

    if tries >= 20 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  local sleep_time = 0.1 * (math.random(750, 1250) / 1000.0)

  if string.match(url["host"], "amazonaws")then
    -- We should be able to go fast on images since that's what a web browser does
    sleep_time = 0
  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  if string.match(url, "https://roon%.io/api/v1/blogs") then
    local content = read_file(file)
    
    if previous_status_code == 404 then
      io.stdout:write("  Nothing to grab here.\n")
      io.stdout:flush()
      return urls
    end

    blog_name = string.match(content, '"url":"http://([%a%d-]+).roon.io/"')

    assert(blog_name)

    io.stdout:write("  Grabbing the blog of " .. blog_name .. ".\n")
    io.stdout:flush()

    local new_url = "http://" .. blog_name .. ".roon.io/"

    table.insert(urls, { url=new_url, link_expect_html=1 })

    local username = string.match(content, '"username":"([^"]+)"')

    assert(username)

    new_url = "https://roon.io/" .. username

    table.insert(urls, { url=new_url, link_expect_html=1 })
  end

  if string.match(url, "roon%.io") then
    local html = read_file(file)

    for extra_url in string.gmatch(html, 'data-2x="(https?://[^"]+)"') do
      table.insert(urls, { url=extra_url })
    end
  end

  return urls
end

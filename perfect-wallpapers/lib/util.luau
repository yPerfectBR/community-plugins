local util = {}

function util.shellQuote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function util.cfg(key, fallback)
  local value = noctalia.getConfig(key)
  if value == nil then
    return fallback
  end
  return value
end

function util.trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return noctalia.string.trim(s)
end

function util.truthy(v)
  return v == true or v == "true"
end

function util.clamp(n, lo, hi)
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

function util.fileExtFromUrl(url, fallback)
  local path = tostring(url):match("([^?]+)") or ""
  local ext = path:match("%.([%w]+)$")
  if ext == nil or ext == "" then
    return fallback or ".bin"
  end
  return "." .. string.lower(ext)
end

function util.joinParams(parts)
  return table.concat(parts, "&")
end

return util

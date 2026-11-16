function clampPercent(n) {
  n = Number(n)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(100, Math.round(n)))
}

function clampInt(n, min, max, fallback) {
  n = Number(n)
  if (!isFinite(n)) return fallback
  n = Math.round(n)
  if (n < min) return min
  if (n > max) return max
  return n
}

var MAX_HELPER_CHARS = 4096
var MAX_LABEL_CHARS = 80
var MAX_NAME_CHARS = 32

function plain(value, max) {
  var limit = max === undefined ? MAX_LABEL_CHARS : max
  var s = String(value === undefined || value === null ? "" : value)
  s = s.replace(/[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]/g, "")
  s = s.replace(/[<>&]/g, "")
  if (s.length > limit) s = s.substring(0, limit)
  return s
}

function sanitizeName(value) {
  var s = plain(value, MAX_NAME_CHARS)
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$/.test(s)) return ""
  if (s === "." || s === "..") return ""
  return s
}

function conserveEndFromSettings(settings) {
  return clampInt(settings && settings.conserveEnd, 50, 95, 80)
}

function packPercent(upowerPercent, capacity) {
  var p = Number(upowerPercent)
  if (isFinite(p)) {
    if (p >= 0 && p <= 1) return clampPercent(p * 100)
    return clampPercent(p)
  }
  return clampPercent(capacity)
}

function fullActive(status) {
  if (!status || !status.supported || !status.ac || status.start !== 99 || status.end !== 100)
    return false
  return status.chargeState === "Charging" || status.chargeState === "Full"
    || (status.chargeState === "Not charging" && status.capacity === 100)
}

function parseStatus(raw) {
  var empty = {
    supported: false,
    writable: false,
    ac: false,
    capacity: 0,
    start: 0,
    end: 0,
    mode: "unknown",
    battery: "",
    chargeState: "Unknown",
    error: ""
  }
  var text = String(raw || "")
  if (text.length > MAX_HELPER_CHARS) {
    empty.error = "invalid-json"
    return empty
  }
  text = text.trim()
  if (!text) return empty
  try {
    var data = JSON.parse(text)
    return {
      supported: !!data.supported,
      writable: !!data.writable,
      ac: !!data.ac,
      capacity: clampPercent(data.capacity),
      start: clampPercent(data.start),
      end: clampPercent(data.end),
      mode: data.mode === "full" ? "full" : (data.mode === "conserve" ? "conserve" : "unknown"),
      battery: sanitizeName(data.battery),
      chargeState: ["Charging", "Discharging", "Full", "Not charging"].indexOf(data.chargeState) >= 0
        ? data.chargeState : "Unknown",
      error: plain(data.error, MAX_LABEL_CHARS)
    }
  } catch (e) {
    empty.error = "invalid-json"
    return empty
  }
}

function pluginFilePath(resolvedUrl) {
  var s = String(resolvedUrl || "")
  if (s.indexOf("file://") === 0) s = decodeURIComponent(s.substring(7))
  if (s.charAt(s.length - 1) === "/") s = s.substring(0, s.length - 1)
  return s
}

function settingsFromConfig(config, pluginId) {
  var found = {}
  function consider(entry) {
    if (!entry || String(entry.id || "") !== String(pluginId || "")) return
    for (var key in entry) {
      if (entry[key] !== undefined) found[key] = entry[key]
    }
  }
  if (config && config.bar && config.bar.layout) {
    var sections = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
    for (var i = 0; i < sections.length; i++) {
      var list = config.bar.layout[sections[i]] || []
      for (var j = 0; j < list.length; j++) consider(list[j])
    }
  }
  var plugins = config && config.plugins ? config.plugins : []
  for (var k = 0; k < plugins.length; k++) consider(plugins[k])
  return found
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_HELPER_CHARS: MAX_HELPER_CHARS,
    clampPercent: clampPercent,
    conserveEndFromSettings: conserveEndFromSettings,
    plain: plain,
    packPercent: packPercent,
    parseStatus: parseStatus,
    fullActive: fullActive,
    pluginFilePath: pluginFilePath,
    settingsFromConfig: settingsFromConfig
  }
}

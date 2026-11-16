const assert = require("assert")
const Model = require("../Model.js")

assert.strictEqual(Model.conserveEndFromSettings({ conserveEnd: 60 }), 60)
assert.strictEqual(Model.conserveEndFromSettings({ conserveEnd: 9 }), 50)
assert.strictEqual(Model.packPercent(0.41, 10), 41)
assert.strictEqual(Model.packPercent(78, 10), 78)
assert.strictEqual(Model.packPercent(undefined, 41), 41)
assert.strictEqual(Model.pluginFilePath("file:///tmp/charge%20limit/"), "/tmp/charge limit")

const parsed = Model.parseStatus('{"supported":true,"writable":true,"ac":false,"capacity":78,"start":75,"end":80,"mode":"conserve","battery":"BAT0","error":""}')
assert.strictEqual(parsed.supported, true)
assert.strictEqual(parsed.capacity, 78)
assert.strictEqual(parsed.end, 80)
assert.strictEqual(parsed.mode, "conserve")
assert.strictEqual(Model.parseStatus("nope").error, "invalid-json")
assert.strictEqual(Model.parseStatus("x".repeat(Model.MAX_HELPER_CHARS + 1)).error, "invalid-json")

const settings = Model.settingsFromConfig({
  bar: { layout: { centerEnd: [{ id: "io.github.k7cfo.charge-100-percent", conserveEnd: 70 }] } },
  plugins: [{ id: "io.github.k7cfo.charge-100-percent" }]
}, "io.github.k7cfo.charge-100-percent")
assert.strictEqual(Model.conserveEndFromSettings(settings), 70)

assert.strictEqual(Model.plain("<img src=https://example.invalid/tracker>BAT0&"), "img src=https://example.invalid/trackerBAT0")
assert.strictEqual(Model.plain("ok\n\tname"), "okname")
assert.strictEqual(Model.parseStatus('{"supported":true,"error":"<img src=x>","battery":"../BAT0","mode":"conserve"}').error, "img src=x")
assert.strictEqual(Model.parseStatus('{"supported":true,"error":"","battery":"../BAT0","mode":"conserve"}').battery, "")

const full = { supported: true, ac: true, start: 99, end: 100, capacity: 78, chargeState: "Charging" }
for (const [changes, expected] of [
  [{}, true],
  [{ chargeState: "Full", capacity: 100 }, true],
  [{ chargeState: "Not charging", capacity: 100 }, true],
  [{ chargeState: "Not charging", capacity: 78 }, false],
  [{ chargeState: "Discharging" }, false],
  [{ chargeState: "Unknown" }, false],
  [{ chargeState: undefined }, false],
  [{ ac: false }, false],
  [{ supported: false }, false],
  [{ start: 75 }, false],
  [{ end: 80 }, false]
]) {
  const status = Model.parseStatus(JSON.stringify({ ...full, ...changes }))
  assert.strictEqual(Model.fullActive(status), expected, JSON.stringify(changes))
}
assert.strictEqual(Model.fullActive(Model.parseStatus("broken")), false)

console.log("Model tests passed")

// Loads modules/common/functions/PluginManifest.js (a QML `.pragma library` file) into
// node, so the tests run the same code the shell does.
const fs = require("fs")
const src = fs.readFileSync(require("./locate")("modules/common/functions/PluginManifest.js"), "utf8").replace(".pragma library", "")
const names = ["API_VERSION", "SUPPORTED", "parse", "mergeSettings", "coerce", "splitScan", "scan", "readState", "expandPath", "readFiles", "FILES"]
module.exports = new Function("console", src + ";return {" + names.map(n => n + ":" + n).join(",") + "}")(console)

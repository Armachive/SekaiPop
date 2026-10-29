// Loads modules/common/functions/PluginRepos.js (a QML `.pragma library` file) into node, so the
// tests run the same code the shell does.
const fs = require("fs")
const src = fs.readFileSync(require("./locate")("modules/common/functions/PluginRepos.js"), "utf8").replace(".pragma library", "")
const names = ["REPO_RE", "versionAtLeast", "parseList", "search", "source", "origin", "repoOf", "groups", "emptyLock", "readLock",
    "withInstall", "withCommit", "withPin", "withPlugins", "withoutRepo", "parseKv", "parseCommit", "parseCheck", "cloneProgress",
    "failure", "checkFound", "namesText", "installSummary", "nextSteps", "kindText", "updates", "batchId", "updatesTitle",
    "noticeBody", "needsChecked", "ageText", "whereText", "sourceLine", "shortId"]
module.exports = new Function("console", src + ";return {" + names.map(n => n + ":" + n).join(",") + "}")(console)

.pragma library

// How often each app is opened from the Apps screen, and the "Most used" order built
// from it (services/AppSource.qml, setting launcher.order). No QML here, so
// tests/app-usage-test can run it under node.
//
// Each app keeps one decaying score instead of a launch history: every launch adds 1,
// and the score halves every HALF_LIFE_DAYS. So an app opened daily for a month and
// then dropped sinks below one opened every day this week, which a plain count would
// never let happen. Only the score and the time of the last launch are stored:
//   { "<desktop id>": { s: <score at t>, t: <ms since epoch> } }
var HALF_LIFE_DAYS = 14;
var DAY_MS = 86400000;
// The store is pruned to this many apps (the lowest scores go first) so it can't grow
// forever on a machine that installs and removes a lot.
var MAX_APPS = 200;
// Below this an app counts as never used: about a single launch eleven weeks ago.
var FORGOTTEN = 0.03;

// The score of `rec` as of `now`.
function scoreAt(rec, now) {
    if (!rec || !(rec.s > 0))
        return 0;
    var age = Math.max(0, now - (rec.t || 0));
    return rec.s * Math.pow(0.5, age / (HALF_LIFE_DAYS * DAY_MS));
}

// A new store with one launch of `id` at `now` added. The store passed in is not changed.
function record(usage, id, now) {
    var out = {};
    for (var k in usage)
        out[k] = usage[k];
    if (!id)
        return out;
    out[id] = { s: scoreAt(usage[id], now) + 1, t: now };
    return prune(out, now);
}

// Drops forgotten apps, then the lowest scores past MAX_APPS.
function prune(usage, now) {
    var ids = [];
    for (var k in usage) {
        if (scoreAt(usage[k], now) >= FORGOTTEN)
            ids.push(k);
    }
    ids.sort(function (a, b) { return scoreAt(usage[b], now) - scoreAt(usage[a], now); });
    var out = {};
    for (var i = 0; i < ids.length && i < MAX_APPS; i++)
        out[ids[i]] = usage[ids[i]];
    return out;
}

// The saved text back into a store. Anything unreadable is an empty store, never an error:
// losing the order is better than an Apps screen that fails to open.
function parse(text) {
    try {
        var j = JSON.parse(text);
        if (!j || typeof j !== "object" || Array.isArray(j))
            return {};
        var out = {};
        for (var k in j) {
            var r = j[k];
            if (r && typeof r.s === "number" && typeof r.t === "number" && r.s > 0)
                out[k] = { s: r.s, t: r.t };
        }
        return out;
    } catch (e) {
        return {};
    }
}

// `entries` (AppSource's entry objects, A to Z, each with `key` and `idx`) most used
// first. Apps never used keep their A to Z order after the used ones. Returns a new
// array of the same objects, so the grid keeps its tiles.
function order(entries, usage, now) {
    var scored = new Array(entries.length);
    for (var i = 0; i < entries.length; i++)
        scored[i] = { e: entries[i], s: scoreAt(usage[entries[i].key], now) };
    scored.sort(function (a, b) { return b.s - a.s || a.e.idx - b.e.idx; });
    return scored.map(function (x) { return x.e; });
}

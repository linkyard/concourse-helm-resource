"use strict";
var child_process_1 = require("child_process");
var lodash_1 = require("lodash");
function readHelmStatus(release) {
    return new Promise(function (fulfill, reject) {
        child_process_1.execFile('helm', ['status', release], function (err, status, stderr) {
            if (err) {
                return reject("Error getting status from helm: " + err + "\n" + stderr);
            }
            fulfill(status);
        });
    });
}
function group(lines, matcher) {
    if (lines.length === 0)
        return [];
    var head = lodash_1.takeWhile(lodash_1.drop(lines, 1), matcher);
    var tail = lodash_1.drop(lines, head.length + 1);
    if (head.length === 0)
        return [tail];
    return [[lines[0]].concat(head)].concat(group(tail, matcher));
}
function parseHelmStatus(status) {
    var lines = status.split('\n');
    var resourceInfos = group(lines, function (line) { return line.length > 0; })
        .map(function (lines) { return lines.filter(function (line) { return line.trim().length > 0; }); })
        .filter(function (group) { return group.length > 0 && group[0].indexOf("==>") === 0; });
    var resources = resourceInfos.map(function (lines) {
        var type = lines[0].substring('==> '.length);
        var values = lodash_1.drop(lines, 2).map(function (line) { return line.split(' '); });
        return [type, values.map(function (value) { return value[0]; })];
    });
    return lodash_1.fromPairs(resources);
}
var release = process.argv[2];
readHelmStatus(release).
    then(parseHelmStatus).
    then(function (a) { return console.log(JSON.stringify(a, null, 2)); });

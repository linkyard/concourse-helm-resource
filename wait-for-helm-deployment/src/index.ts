import {execFile} from 'child_process'
import {parseHelmStatus, Resource} from './parse-helm'
import {clearLine} from 'readline'
import {moveCursor} from 'readline'

const interval = 1000 //ms
const defaultTimeout = 300000 //ms

function readHelmStatus(release) {
  return new Promise<string>((fulfill, reject) => {
    execFile('helm', ['status', release], function (err, status, stderr) {
      if (err) {
        return reject(`Error getting status from helm: ${err}\n${stderr}`)
      }
      fulfill(status)
    })
  })
}

const t0 = Date.now()
let timeoutExpired = false

let deleteLines = 0

function checkReady(status: Resource[]) {
  const notReady = status.filter(resource => !resource.isReady)
    .map(resource => `- ${resource.name} (${resource.type})`)
  if (notReady.length > 0) {
    const seconds = Math.round((Date.now() - t0) / 1000)
    for (let i = 0; i<deleteLines; i++) {
      moveCursor(process.stdout, 0, -1)
      clearLine(process.stdout, 0)
    }
    process.stdout.write(`The following resources are not ready yet (after ${seconds}s):\n${notReady.sort().join('\n')}\n`)
    deleteLines = notReady.length + 1
    return false
  }
  return true
}

function waitUntilReady(release) {
  readHelmStatus(release)
    .then(parseHelmStatus)
    .then(checkReady).then(ready => {
    if (ready) return process.exit(0)
    else setTimeout(() => {
      if (timeoutExpired) {
        console.log(`Timeout expired while waiting for ${release} to become ready, aborting.`)
        return process.exit(55)
      }
      waitUntilReady(release)
    }, interval)
  })
}

const release = process.argv[2]
const timeout = (parseInt(process.argv.length > 3 && process.argv[3]) * 1000) || defaultTimeout
setTimeout(() => timeoutExpired = true, timeout)

waitUntilReady(release)

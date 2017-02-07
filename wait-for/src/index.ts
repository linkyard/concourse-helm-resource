import {execFile} from 'child_process'
import {parseHelmStatus} from './parse-helm'

function readHelmStatus(release) {
  return new Promise<string>((fulfill, reject) => {
    execFile('helm', ['status', release], function(err, status, stderr) {
      if (err) {
        return reject(`Error getting status from helm: ${err}\n${stderr}`)
      }
      fulfill(status)
    })
  })
}


const release = process.argv[2]
readHelmStatus(release).
  then(parseHelmStatus).
  then(a => console.log(JSON.stringify(a, null, 2)))

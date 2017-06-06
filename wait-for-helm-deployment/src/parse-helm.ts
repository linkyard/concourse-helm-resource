import {takeWhile, drop, dropWhile, flatMap} from 'lodash'

function group<a>(lines: a[], matcher: (item: a) => boolean): a[][] {
  if (lines.length === 0) return []

  const head = takeWhile(drop(lines, 1), matcher)
  const tail = drop(lines, head.length + 1)

  if (head.length === 0)
    return [tail]
  return [[lines[0], ...head], ...group(tail, matcher)]
}

export function parseHelmStatus(status: string): Resource[] {
  const lines = status.split('\n')
  const afterHeader = drop(dropWhile(lines, line => line !== 'RESOURCES:'), 1)
  const resourceInfos = group(afterHeader, (line: string) => line.length > 0)
    .map(lines => lines.filter(line => line.trim().length > 0))
    .filter(group => group.length > 0 && group[0].indexOf("==>") === 0)
      const resources = flatMap(resourceInfos, (lines: string[]) => {
      const type = lines[0].substring('==> '.length)
      const simpleTypeMatcher = /^.*?\/([^\/]+)$/g
      const simpleTypeMatches = simpleTypeMatcher.exec(type)
      const simpleType = simpleTypeMatches ? simpleTypeMatches[1] : type
      const values = drop(lines, 2).map(line => line.split(/ +/))
      return values.map(value => parseResource(type, simpleType, value))
  })
  return resources
}

export interface Resource {
  name: string
  /** Kubernetes API type of this resource (eg v1/Service). */
  type: string
  /** Simplified kubernetes API type of this resource (without the prefix, eg Service). */
  simpleType: string
  /** true if the resource is ready - returns true for things that don't have a state such as Secrets */
  isReady: boolean

  desired?: number
  current?: number
  upToDate?: number
  available?: number
  successful?: number

  volume?: string
}

function parseResource(type: string, simpleType, columns: string[]): Resource {
  switch (simpleType) {
    case 'Job':
      //NAME                     DESIRED   SUCCESSFUL   AGE
      const desired = parseInt(columns[1])
      const successful = parseInt(columns[2])
      return {
        type,
        simpleType,
        name: columns[0],
        desired,
        successful,
        isReady: desired === successful
      }

    case 'PersistentVolumeClaim':
      //NAME             STATUS    VOLUME      CAPACITY   ACCESSMODES   AGE
      return {
        type,
        simpleType,
        name: columns[0],
        volume: columns[2],
        isReady: columns[1] === 'Bound'
      }
    case 'Deployment':
      //NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
      return {
        type,
        simpleType,
        name: columns[0],
        desired: parseInt(columns[1]),
        current: parseInt(columns[2]),
        upToDate: parseInt(columns[3]),
        available: parseInt(columns[4]),
        isReady: parseInt(columns[4]) > 0 // ready if at least one is available
      }
    default:
      return {
        type,
        simpleType,
        name: columns[0],
        isReady: true
      }
  }
}

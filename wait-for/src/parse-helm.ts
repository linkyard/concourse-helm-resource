import {takeWhile, drop, dropWhile, fromPairs} from 'lodash'

function group<a>(lines: a[], matcher: (item: a) => boolean): a[][] {
  if (lines.length === 0) return []

  const head = takeWhile(drop(lines, 1), matcher)
  const tail = drop(lines, head.length + 1)

  if (head.length === 0)
    return [tail]
  return [[lines[0], ...head], ...group(tail, matcher)]
}

export function parseHelmStatus(status: string) {
  const lines = status.split('\n')
  const resourceInfos = group(lines, (line: string) => line.length > 0)
    .map(lines => lines.filter(line => line.trim().length > 0))
    .filter(group => group.length > 0 && group[0].indexOf("==>") === 0)
  const resources = resourceInfos.map((lines: string[]) => {
    const type = lines[0].substring('==> '.length)
    const values = drop(lines, 2).map(line => line.split(' '))
    return [type, values.map(value => value[0])]
  })
  return fromPairs(resources)
}

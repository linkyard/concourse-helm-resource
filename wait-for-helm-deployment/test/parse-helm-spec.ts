import {expect} from 'chai'
import 'mocha'
import {parseHelmStatus, Resource} from '../src/parse-helm'

describe('parse helm status', () => {
  it('should not fail on an empty string', () => {
    const status = parseHelmStatus('')
    expect(status).to.be.empty
  })

  it('should not fail without resources', () => {
    const status = parseHelmStatus(withoutResources)
    expect(status).to.be.empty
  })

  it('should not fail without resources ending on empty line', () => {
    const status = parseHelmStatus(withoutResources + '\n')
    expect(status).to.be.empty
  })

  it('should parse all names and types from example1', () => {
    const status = parseHelmStatus(example1)
    expect(status).to.have.lengthOf(3)
    expect(status[0].name).to.equal('cit-nginx')
    expect(status[0].type).to.equal('v1/ConfigMap')
    expect(status[1].name).to.equal('cit-nginx')
    expect(status[1].type).to.equal('v1/Service')
    expect(status[2].name).to.equal('cit-nginx')
    expect(status[2].type).to.equal('extensions/Deployment')
  })

  it('should parse all names and types from example2', () => {
    const status = parseHelmStatus(example2)
    expect(status).to.have.lengthOf(18)
    expect(status[0].name).to.equal('ht-jira-sd-mail')
    expect(status[0].type).to.equal('v1/ConfigMap')
    expect(status[1].name).to.equal('ht-kc-postgres')
    expect(status[1].type).to.equal('v1/Service')
    expect(status[2].name).to.equal('ht-jira-sd')
    expect(status[2].type).to.equal('v1/Service')
    expect(status[3].name).to.equal('ht-sd-postgres')
    expect(status[3].type).to.equal('v1/Service')
    expect(status[4].name).to.equal('ht-keycloak')
    expect(status[4].type).to.equal('v1/Service')
    expect(status[5].name).to.equal('ht-jira-sd')
    expect(status[5].type).to.equal('extensions/Deployment')
    expect(status[6].name).to.equal('ht-sd-postgres')
    expect(status[6].type).to.equal('extensions/Deployment')
    expect(status[7].name).to.equal('ht-kc-postgres')
    expect(status[7].type).to.equal('extensions/Deployment')
    expect(status[8].name).to.equal('ht-keycloak')
    expect(status[8].type).to.equal('extensions/Deployment')
    expect(status[9].name).to.equal('ht-xxx')
    expect(status[9].type).to.equal('extensions/Ingress')
    expect(status[10].name).to.equal('ht-jira-sd-setup-lh6cg')
    expect(status[10].type).to.equal('batch/Job')
    expect(status[11].name).to.equal('ht-kc-postgres')
    expect(status[11].type).to.equal('v1/PersistentVolumeClaim')
    expect(status[12].name).to.equal('ht-jira-sd')
    expect(status[12].type).to.equal('v1/PersistentVolumeClaim')
    expect(status[13].name).to.equal('ht-sd-postgres')
    expect(status[13].type).to.equal('v1/PersistentVolumeClaim')
    expect(status[14].name).to.equal('ht-keycloak')
    expect(status[14].type).to.equal('v1/Secret')
    expect(status[15].name).to.equal('ht-jira-sd')
    expect(status[15].type).to.equal('v1/Secret')
    expect(status[16].name).to.equal('ht-kc-postgres')
    expect(status[16].type).to.equal('v1/Secret')
    expect(status[17].name).to.equal('ht-sd-postgres')
    expect(status[17].type).to.equal('v1/Secret')
  })

  it('should see any service as ready', () => {
    const status = parseHelmStatus(example1)
    expect(status[1].type).to.equal('v1/Service')
    expect(status[1].isReady).to.be.true
  })

  it('should see any secret as ready', () => {
    const status = parseHelmStatus(example2)
    expect(status[16].type).to.equal('v1/Secret')
    expect(status[16].isReady).to.be.true
  })

  it('should see any config map as ready', () => {
    const status = parseHelmStatus(example1)
    expect(status[0].type).to.equal('v1/ConfigMap')
    expect(status[0].isReady).to.be.true
  })

  it('should see a deployment with at least one available as ready', () => {
    const status = parseHelmStatus(example3)
    expectDeployment(status[0], 'd1',
      1, 0, 0, 0, false)
    expectDeployment(status[1], 'd2',
      2, 1, 1, 0, false)
    expectDeployment(status[2], 'd3',
      3, 2, 1, 1, true)
    expectDeployment(status[3], 'd4',
      2, 2, 2, 2, true)
  })

  function expectDeployment(deployment: Resource, name, desired, current, upToDate, available, ready) {
    expect(deployment.type).to.equal('extensions/Deployment')
    expect(deployment.name).to.equal(name)
    expect(deployment.desired).to.equal(desired)
    expect(deployment.current).to.equal(current)
    expect(deployment.upToDate).to.equal(upToDate)
    expect(deployment.available).to.equal(available)
    expect(deployment.isReady).to.equal(ready)
  }

  it('should see a pvc that is bound as ready', () => {
    const status = parseHelmStatus(example3)
    expect(status[4].type).to.equal('v1/PersistentVolumeClaim')
    expect(status[4].name).to.equal('p1')
    expect(status[4].isReady).to.be.true
    expect(status[5].type).to.equal('v1/PersistentVolumeClaim')
    expect(status[5].name).to.equal('p2')
    expect(status[5].isReady).to.be.false
  })

  it('should see a job that has all desired completed as ready', () => {
    const status = parseHelmStatus(example3)
    expectJob(status[6], 'j1', 1, 0, false)
    expectJob(status[7], 'j2', 1, 1, true)
    expectJob(status[8], 'j3', 2, 1, false)
  })

  function expectJob(job: Resource, name, desired, successful, ready) {
    expect(job.type).to.equal('batch/Job')
    expect(job.name).to.equal(name)
    expect(job.desired).to.equal(desired)
    expect(job.successful).to.equal(successful)
    expect(job.isReady).to.equal(ready)

  }
})


const withoutResources = `
LAST DEPLOYED: Tue Feb  7 10:50:22 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:`

const example1 = `
LAST DEPLOYED: Tue Feb  7 10:50:22 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME        DATA      AGE
cit-nginx   2         11h

==> v1/Service
NAME        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
cit-nginx   172.20.153.46   <none>        8888/TCP   11h

==> extensions/Deployment
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cit-nginx   1         1         1            1           11h`;

const example2 = `
LAST DEPLOYED: Fri Feb  3 23:05:34 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME              DATA      AGE
ht-jira-sd-mail   7         10d

==> v1/Service
NAME             CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
ht-kc-postgres   172.20.240.105   <none>        5432/TCP   10d
ht-jira-sd   172.20.114.7   <none>    80/TCP    10d
ht-sd-postgres   172.20.154.242   <none>    5432/TCP   10d
ht-keycloak   172.20.16.117   <none>    80/TCP    10d

==> extensions/Deployment
NAME         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
ht-jira-sd   1         1         1            1           10d
ht-sd-postgres   1         1         1         1         10d
ht-kc-postgres   1         1         1         1         10d
ht-keycloak   1         1         1         1         10d

==> extensions/Ingress
NAME      HOSTS                                        ADDRESS          PORTS     AGE
ht-xxx    xxx.test.linkyard.ch,id.xxx.test.linkyard.ch   37.187.164.231   80, 443   10d

==> batch/Job
NAME                     DESIRED   SUCCESSFUL   AGE
ht-jira-sd-setup-lh6cg   1         0            3d

==> v1/PersistentVolumeClaim
NAME             STATUS    VOLUME      CAPACITY   ACCESSMODES   AGE
ht-kc-postgres   Bound     local-080   0                        10d
ht-jira-sd   Bound     local-014   0                   10d
ht-sd-postgres   Bound     local-021   0                   10d

==> v1/Secret
NAME          TYPE      DATA      AGE
ht-keycloak   Opaque    2         10d
ht-jira-sd   Opaque    2         10d
ht-kc-postgres   Opaque    2         10d
ht-sd-postgres   Opaque    2         10d


NOTES:
Your instance is now starting...
`


const example3 = `
LAST DEPLOYED: Tue Feb  7 10:50:22 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> extensions/Deployment
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
d1          1         0         0            0           11h
d2          2         1         1            0           11h
d3          3         2         1            1           11h
d4          2         2         2            2           11h

==> v1/PersistentVolumeClaim
NAME             STATUS    VOLUME      CAPACITY   ACCESSMODES   AGE
p1               Bound     local-080   0                        10d
p2               NotBound  local-080   0                        10d

==> batch/Job
NAME                     DESIRED   SUCCESSFUL   AGE
j1                       1         0            3d
j2                       1         1            3d
j3                       2         1            3d
`

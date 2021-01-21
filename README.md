# Pipelines
Repository für die im AGI Jenkins betriebenen Pipelines

## Betrieb Pipelines
Die Pipelines werden von Jenkins aus gestartet. Theoretisch könnten diese direkt aus Openshift gestartet werden, aber hier gibt es bspw. Einschränkungen mit dem Starten von "Kind Pipelines" wie dies z.B. bei der API-Web GIS Client Pipeline notwendig ist, wo die Pipelines der einzelnen Services in einer "Eltern Pipeline" orchestriert werden => https://github.com/openshift/jenkins-sync-plugin#restrictions.
Ausserdem ist ein Zugriff auf Jenkins für GDI/AGI externe Personen unproblematischer zu sehen, als ein Zugriff auf Openshift und kann in Jenkins auch feiner granuliert werden.

Für jede Pipeline wird in diesem Repo ein eigener Ordner angelegt. In diesem befindet sich das Jenkinsfile, so wie alle für die Ausführung der Pipeline erforderlichen Files.

Dem von Jenkins genutzten ServiceAccount müssen die notwendigen Rechte gegeben werden um über die API in anderen Namespaces Anpassungen vorzunehmen.
Dies macht man mit 
```
oc policy add-role-to-user edit system:serviceaccount:agi-apps-integration:jenkins -n gdi-devel
```
Hier werden bspw dem jenkins serviceaccount im Namespace *agi-apps-integration* edit Rechte im Namespace *gdi-devel* gegeben.

Damit Unterhalt und Entwicklung der Pipelines sauber gewährleistet werden kann muss beim Anlegen einer Pipeline folgendes beachtet werden.

In Jenkins wird unter https://jenkins-agi-apps-test.dev.so.ch/configure eine globale Variable *branch_pipelinename* angelegt, wobei *pipelinename* durch den Name der Pipeline zu ersetzen ist. Als Wert für die Variable wird der aktuell in der Umgebung verwendete Branchname gesetzt.

In der Konfiguration der Pipeline unter https://jenkins-agi-apps-test.dev.so.ch/job/pipelinename/configure (auch hier *pipelinename* wieder durch den Namen der Pipeline ersetzen) wird im Reiter *Pipeline* unter *Branches to build* der Name der globalen Variable eingesetzt.
![](https://github.com/sogis/pipelines/blob/master/setBranchesToBuild.png)

Wenn es sich um eine einzelne Pipeline handelt kann der Name des Branches auch direkt unter *Branches to build* gesetzt werden. Die globale Variable ist dann nicht notwendig.

Diese macht vor allem bei Gruppen von ähnlichen Pipelines wie z.B. beim api_webgisclient Sinn.

### Jenkins Shared Libraries
In Jenkins können für häufig genutzten Code, der in mehreren Pipelines verwendet werden soll, sogenannte Shared Libraries verwendet werden => https://www.jenkins.io/doc/book/pipeline/shared-libraries/

Für das AGI findet man die Shared Library unter https://github.com/sogis/jenkins-shared-libs. Falls notwendig können hier weitere Klassen ergänzt werden.
Für die Nutzung der Shared Library wird in der Jenkins Konfiguration die Globale Variable JENKINS_SHARED_LIBS_BRANCH gesetzt. Hier wird der Branch der Shared Library eingetragen, der in der Jenkins Umgebung verwendet wird.
Die Anpassung erfolgt unter https://jenkins-agi-apps-test.dev.so.ch/configure
![](https://github.com/sogis/pipelines/blob/master/createGlobalVar.png)

## Unterhalt Pipelines
Jenkins steht auf den drei Umgebungen Prod,Integration und Test zur Verfügung.
Für Anpassungen an den Pipelines wird jeweils ein separater Branch des pipeline Repos erstellt in dem die Anpassungen vorgenommen werden.

Im Jenkins ist dann für die entsprechende Pipeline der Name des Branches entweder in der globalen Variable des Branches oder direkt in der Pipeline Konfiguration anzupassen.

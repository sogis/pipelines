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

### Jenkins Shared Libraries
In Jenkins können für häufig genutzten Code, der in mehreren Pipelines verwendet werden soll, sogenannte Shared Libraries verwendet werden => https://www.jenkins.io/doc/book/pipeline/shared-libraries/

Für das AGI findet man die Shared Library unter https://github.com/sogis/jenkins-shared-libs. Falls notwendig können hier weitere Klassen ergänzt werden.
Für die Nutzung der Shared Library wird in der Jenkins Konfiguration die Globale Variable JENKINS_SHARED_LIBS_BRANCH gesetzt. Hier wird der Branch der Shared Library eingetragen, der in der Jenkins Umgebung verwendet wird.
Die Anpassung erfolgt unter https://jenkins-agi-apps-test.dev.so.ch/configure
![](https://github.com/sogis/pipelines/blob/master/createGlobalVar.png)

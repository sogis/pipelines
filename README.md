# AGI Pipelines
Pipelines for AGI GDI

## Betrieb Jenkins
Die Pipelines werden mit dem in Openshift enthaltenen Jenkins betrieben.
Es wird dafür die persistierte Jenkins Variante verwendet. Der Vorteil ist, dass der durch Openshift deployte Jenkins durch eine Reihe von Openshift Jenkins Plugins vollständig mit Openshift gekoppelt ist.
Einerseits kann so direkt auf Ressourcen innerhalb des Projekts zugegriffen werden, andererseits können durch entsprechendes Labelling dynamische Slaves aufgesetzt werden. Des Weiteren wird auch ein entsprechender Serviceaccount (jenkins) erstellt. Die Rechtevergabe kann entsprechend über diesen Serviceacount erfolgen.
Zum Einsatz kommt das Openshift Jenkins Client Plugin (direkte Kommunikation mit Openshift Cluster), das Openshift Jenkins Sync Plugin und das Kubernetes Plugin.
Der Jenkins wird im Namespace AGI Applications betrieben.

### Installation Jenkins in Openshift
Für die Installation wurde das in Openshift enthaltene Template leicht angepasst.
So wird nun anstelle des in der Openshift Registry enthaltenen und veralteten Jenkins Images das Image *openshift/jenkins-2-centos7:v3.11* verwendet. Dieses ist aktueller und wird auch für den Gretl-Jenkins verwendet.
Ausserdem wurden alle Resourcen Angaben parametrisiert und für die Verwendung des Images in der DeploymentConfig muss noch ein ImageStream erstellt werden.
Die Installation in Openshift im Projekt *projectname* erfolgt mit den folgenden Befehlen. Diverse Parameter sind im Template enthalten und können angepasst werden.
Im AGI werden allerdings die definierten Defaults verwendet.

```
oc login
oc project projectname
git clone https://github.com/sogis/pipelines.git
cd pipelines
oc process -f jenkins-persistent-template.yaml | oc apply -f-
```
Das Login im Jenkins erfolgt über Openshift OAuth Authentifizierung, die vom Openshift Login Plugin zur Verfügung gestellt wird

## Betrieb Pipelines
Die Pipelines werden von Jenkins aus gestartet. Theoretisch könnten diese direkt aus Openshift gestartet werden, aber hier gibt es bspw. Einschränkungen mit dem Starten von "Kind Pipelines" wie dies z.B. bei der API-Web GIS Client Pipeline notwendig ist, wo die Pipelines der einzelnen Services in einer "Eltern Pipeline" orchestriert werden => https://github.com/openshift/jenkins-sync-plugin#restrictions.
Ausserdem ist ein Zugriff auf Jenkins für GDI/AGI externe Personen unproblematischer zu sehen, als ein Zugriff auf Openshift und kann in Jenkins auch feiner granuliert werden.

Für jede Pipeline wird ein eigener Ordner angelegt. Dort befindet sich das Jenkinsfile, so wie alle für die Ausführung der Pipeline erforderlichen Files.
Dies wären z.B. ImageStream Definitionen für erforderliche Custom Slaves, Secrets für Zugriffe auf geschützte Repos oder auch für einen Image Build erforderliche Dateien, sofern es dafür kein Applikationsrepository gibt bzw. diese dort nicht abgelegt werden können (Beispiel Konfigurationsdateien für extern entwickelte Software mit verschiedenen Usern).

Dem von Jenkins genutzten ServiceAccount müssen die notwendigen Rechte gegeben werden um über die API in anderen Namespaces Anpassungen vorzunehmen.
Dies macht man mit 
```
oc policy add-role-to-user edit system:serviceaccount:agi-apps-integration:jenkins -n gdi-devel
```
Hier werden bspw dem jenkins serviceaccount im namespace agi-apps-integration edit Rechte im Namespace gdi-devel gegeben.

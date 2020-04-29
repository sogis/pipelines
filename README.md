# AGI Pipelines
Pipelines for AGI GDI

## Betrieb Jenkins
Die Pipelines werden mit dem in Openshift enthaltenen Jenkins betrieben.
Es wird dafür die persistierte Jenkins Variante verwendet. Der Vorteil ist, dass der durch Openshift deployte Jenkins durch eine Reihe von Openshift Jenkins Plugins vollständig mit Openshift gekoppelt ist.
Einerseits kann so direkt auf Ressourcen innerhalb des Projekts zugegriffen werden, andererseits können durch entsprechendes Labelling dynamische Slaves aufgesetzt werden. Des Weiteren wird auch ein entsprechender Serviceaccount (jenkins) erstellt. Die Rechtevergabe kann entsprechend über diesen Serviceacount erfolgen.
Zum Einsatz kommt das Openshift Jenkins Client Plugin (direkte Kommunikation mit Openshift Cluster), das Openshift Jenkins Sync Plugin und das Kubernetes Plugin.
Der Jenkins wird im Namespace AGI Applications betrieben.

## Betrieb Pipelines
Die Pipelines werden von Jenkins aus gestartet. Theoretisch könnten diese direkt aus Openshift gestartet werden, aber hier gibt es bspw. Einschränkungen mit dem Starten von "Kind Pipelines" wie dies z.B. bei der API-Web GIS Client Pipeline notwendig ist, wo die Pipelines der einzelnen Services in einer "Eltern Pipeline" orchestriert werden => https://github.com/openshift/jenkins-sync-plugin#restrictions.
Ausserdem ist ein Zugriff auf Jenkins für GDI/AGI externe Personen unproblematischer zu sehen, als ein Zugriff auf Openshift und kann in Jenkins auch feiner granuliert werden.

Für jede Pipeline wird ein eigener Ordner angelegt. Dort befindet sich das Jenkinsfile, so wie alle für die Ausführung der Pipeline erforderlichen Files.
Dies wären z.B. ImageStream Definitionen für erforderliche Custom Slaves, Secrets für Zugriffe auf geschützte Repos oder auch für einen Image Build erforderliche Dateien, sofern es dafür kein Applikationsrepository gibt bzw. diese dort nicht abgelegt werden können (Beispiel Konfigurationsdateien für extern entwickelte Software mit verschiedenen Usern).

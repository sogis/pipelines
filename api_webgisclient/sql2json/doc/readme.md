# Json Templating Views und Queries

Die von den sql2json ausgelösten queries verwenden teilweise gemeinsame SQL Views. Die Views wiederum sind untereinander abhängig.
Das folgende Diagramm dokumentiert die Abhängigkeiten.

![query_dependencies](query_dependencies.png)
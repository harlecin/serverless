# Ziel

## Enduser Sicht

    input -> cloud function -> output

Ich schreibe R-Code und möchte eine Funktion definieren, die ich in die Cloud pushe. Dort liegt sie bis ich sie aufrufe. 

1. Funktion definieren und nach Azure uploaden
   * Ich schreibe eine R-Funktion and übergebe dann den Namen der Funktion der `serverless deploy` Funktion.
   * Ein interaktiver Sub-Prozess mit Menüführung wird gestartet und Informationen wie die Azure `subsription`, `ressource group` Name, etc wird vom User abgefragt.
   * Als `return` erhalte ich den Endpoint als String bzw. ein Objekt, das noch mehr Informationen enthält.
2. Funktion nutzen
   * Das Objekt nutzend kann ich nun jederzeit die deployed function mit den benötigten Parametern aufrufen. 
3. Funktion anhalten oder löschen
   * Möglichkeit den Plan zu löschen, da er ja ständig Kosten verursacht (gibt kein Anhalten mWn)
   * RG löschen

### Anmerkungen

* Wenn wir es auf der `ACR` haben können wir auch in Richtung `ACI` gehen und da dann oft deutlich kostengünstigere agieren, je nachdem wie oft und schnell die Funktion benötigt wird. 
* Lokales Testen der Funktion wird noch sehr interessant. 

# Prozess

## `Bash` Sicht (Azure + Docker)

1. `az login`
2. Variablennamen definieren wie `region`, `rg`, `function_name`
3. Docker Image definieren und holen
4. `az group create`
5. `az acr create`
6. `az acr login`
7. `docker build`
8. `docker tag`
9. `docker push`
10. `az functionapp plan create`
11. `az functionapp create`

## Templating

1. Übergabe der zu deployenden Funktion an `serverless deploy` Funktion
   * Rückfrage nach Endpoint Namen
2. Code der Funktion
   * **WRITE:** komplette Funktion inklusive Parameter in `handler.R`
   * **WRITE:** korrektes `plumbr` tagging sicherstellen
     * `GET` oder `POST` sowie Endpoint Name (=Ordner mit `function.json`)
3. Feststellen der benötigten Input `parameter`
   * **WRITE:** Anlegen des Endpoint Ordners. Unterscheidung in `GET` oder `POST` in `function.json`
4. Feststellen der benötigten `packages`
   * **WRITE:** String für `install.packages` in `DOCKERFILE`

# Prerequisites

Drawing heavily from David Smith' [R-custom-handler](https://github.com/revodavid/R-custom-handler).

## Installed on user system

* R
* Azure Subscription
* Azure CLI
* Azure Functions Core Tools
* Docker
  * brauch ich nicht, wenn ich über ACR und ein öffentliches git repo builden lasse
  * ergo: entweder Docher Hub oder (öffentliches) github und ACR oder lokal und ACR

## packages

* `plumbr`
* `renv`
  * um verwendete Pakete zu identifizieren und als String ins Dockerfile einzufügen
* `whisker`
  * Template Engine
* `cloudyR`
  * Authentifizierung, Ressourcenerstellung
  * Alternative: `httr` und alles über HTTP calls

## files

<details>
<summary><code>handler.R</code></summary>

```R
library(plumber)
library(jsonlite) #notwendig?
#* Predict probability of fatality from params in body
#* @post /api/accident
function(params) {
  model_path <- "."
  model <- readRDS(file.path(model_path, "model.rds"))
  method <- model$method

  message(paste(method, "model loaded"))
  
  prediction <- predict(model, newdata=params, type="prob")[,"dead"]

  return(prediction)
}
```
</details>

<details>
<summary><code>host.json</code></summary>

```R
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[1.*, 2.0.0)"
  },
  "customHandler": {
    "description": {
      "defaultExecutablePath": "Rscript",
      "workingDirectory": "",
      "arguments": [ "launch-service.R" ]
    },
    "enableForwardingHttpRequest": true
  }
}
```
</details>

<details>
<summary><code>launch-service.R</code></summary>

```R
library(plumber)

PORTEnv <- Sys.getenv("FUNCTIONS_CUSTOMHANDLER_PORT")
PORT <- strtoi(PORTEnv , base = 0L)
if(is.na(PORT)) PORT <- 8000

message(paste0("Launching server listening on :", PORT, "...\n"))

pr("handler.R") %>%
  pr_run(port=PORT)
```
</details>

<details>
<summary>folder für endpoints mit jeweils <code>function.json</code> drin (e.g. 'accident/function.json')</summary>

```R
{
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": [
        "get",
        "post"
      ]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "res"
    }
  ]
}
```
</details>
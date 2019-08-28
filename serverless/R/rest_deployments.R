library('httr')
library('rjson')
library('whisker')

#' runs eintire workflow
#'
#' runs everything
runAll <- function() {

  # library(httr)
  # library(jsonlite)

  loadConfig()

  token <- getToken()

  getResourceGroupRest()

  createResourceGroup(resource_group = resource_group,
                      location = location)

  createRegistry(resource_group = resource_group,
                 registry_name = registry_name)

  secrets <- getACRSecret(resource_group = resource_group,
                          registry_name = registry_name)

  createACRTask(resource_group = resource_group,
                registry_name = registry_name,
                task_name = task_name,
                secrets = secrets)

  createACI(resource_group = resource_group,
            registry_name = registry_name,
            container_name = container_name)

  manageACI(resource_group = resource_group,
            container_name = container_name,
            action = "stop")
}

#' create Resource Group
#'
#' loads all necessary variables
loadConfig <- function() {

  # personal information
  # i.e. git_url, git_pat, Azure subscription
  source(file.path("R", "config.R"))

  # Azure
  app_name <<- "azure_mgmt"
  client_id <<- "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
  client_secret <<- NULL

  # server config
  location <<- "westeurope"
  resource_group <<- "serverless-rg"

  # ACR
  registry_name <<- "serverlessacr"
  sku <<- "Basic"

  # ACR Task
  task_name <<- "serverless-acr-task"
  image_name <<- "serverless-image"
  image_tag <<- "latest"

  # ACI
  container_name <<- "serverless-aci"
  container_cpu <<- 1
  container_memory <<- 1

}

#' list Resource Groups
#'
#' list Resource Groups.
#' This function might be deleted soon.
#'
#' @param app_name name of app
#' @param client_id client id of Azure CLI
#' @param client_secret stays NULL,
getToken <- function(app_name = "test",
                     client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46",
                     client_secret = NULL) {

  # make sure client_secret is NULL
  # ToDo: probably obsolete
  if(!is.null(client_secret)) {
    stop("client secret has to be NULL")
  }

  # check if token already exists and break
  if(exists("token")) {
    return(token)
  }

  resource_uri = "https://management.core.windows.net/"

  # Endpoints are of the form:
  # https://login.windows.net/<common | tenant-id>/oauth2/<authorize | token>
  azure_endpoint = oauth_endpoint(authorize = "https://login.windows.net/common/oauth2/authorize",
                                  access = "https://login.windows.net/common/oauth2/token")

  azure_app = oauth_app(
    appname = app_name,
    key = client_id,
    secret = client_secret
  )

  token_env <- oauth2.0_token(azure_endpoint, azure_app,
                              user_params = list(resource = resource_uri),
                              use_oob = FALSE
  )

  token <- token_env$credentials$access_token
  return(token)

}

## STEP 4.0 ##
#' list Resource Groups
#'
#' list Resource Groups.
#' This function might be deleted soon.
getResourceGroupRest <- function() {

  # ToDo: create Regex check
  if(subscription == "") {
    stop("missing subscription")
  }

  # REST call for GET
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourcegroups?api-version=2019-05-10")

  # get token
  token <- getToken()

  # GET call
  response <- GET(url = url,
                  add_headers(.headers = c(
                    "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                    ,"Content-Type" = "application/json")
                  ),
                  encode = "json"
  )
  response <- makeGETRestCall(url)

  # parse response
  parsed_response <- content(response, "parsed")

  # ToDo: to complete
  retrieved_resource_groups <- parsed_response$value[[1]]$name

  # check response
  if(is.character(retrieved_resource_groups)) {
    print(TRUE)
  } else {
    print(FALSE)
  }

}

## STEP 4.1 ##
#' create Resource Group
#'
#' creates the resource group
#'
#' @param resource_group name of resource group
#' @param location the location of the resource group
createResourceGroup <- function(resource_group,
                                location) {

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourcegroups/{resource_group}?api-version=2019-05-10")

  # get token
  token <- getToken()

  # read body json
  data = list(location = location)
  body = fillJsonTemplate(file_name = "rest_body_resource_group.json",
                          data = data)

  # PUT call
  response <- httr::PUT(url = url,
                        add_headers(.headers = c(
                          "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                          ,"Content-Type" = "application/json")
                        ),
                        body = body,
                        encode = "json"
  )

  # parse response
  parsed_response <- content(response, "parsed")

  # check response
  if(parsed_response$properties$provisioningState == "Succeeded") {
    return(TRUE)
  } else {
    return(FALSE)
  }

}

## STEP 4.2 ##
#' create ACR
#'
#' deploys the Azure Container Registry
#'
#' @param resource_group name of resource group
#' @param registry_name name of Azure Container Registry
createRegistry <- function(resource_group,
                           registry_name) {


  # ToDo: Create check for alphanumeric name for registry name

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resource_group}/providers/Microsoft.ContainerRegistry/registries/{registry_name}?api-version=2019-05-01")

  # get token
  token <- getToken()

  # read body json
  data = list(location = location,
              sku = sku)
  body = fillJsonTemplate(file_name = "rest_body_acr.json",
                          data = data)

  # POST call
  response <- httr::PUT(url = url,
                        add_headers(.headers = c(
                          "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                          ,"Content-Type" = "application/json")
                        ),
                        body = body,
                        encode = "json"
  )

  # parse response
  parsed_response <- content(response, "parsed")

  # check response
  if(parsed_response$properties$provisioningState == "Succeeded") {
    return(TRUE)
  } else {
    return(FALSE)
  }

}

## STEP 5 ##
#' get ACR secret
#'
#' get the Azure Container Registry username and password
#'
#' @param resource_group name of resource group
#' @param registry_name name of Azure Container Registry
#' @return a list with the ACR secrets
getACRSecret <- function(resource_group,
                         registry_name) {

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resource_group}/providers/Microsoft.ContainerRegistry/registries/{registry_name}/listCredentials?api-version=2019-05-01")

  # get token
  # token <- getToken()

  # POST call
  # response <- POST(url = url,
  #     add_headers(.headers = c(
  #       "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
  #       ,"Content-Type" = "application/json")
  #     ),
  #     encode = "json"
  # )

  response <- makePOSTRestCall(url = url)

  # parse response
  parsed_response <- content(response, "parsed")

  # get credentials
  acr_username <- parsed_response$username
  acr_password <- parsed_response$passwords[[1]][[2]]

  acr_creds <- list(user = acr_username, pass = acr_password)
  return(acr_creds)
}

## STEP 6 ##
#' create ACR task
#'
#' creates the Azure Container Registry task that builds the docker image from the git repo
#'
#' @param resource_group name of resource group
#' @param registry_name name of Azure Container Registry
#' @param task_name name of Azure Container Registry task
#' @param secrets list of username and password for ACR
createACRTask <- function(resource_group,
                          registry_name,
                          task_name,
                          secrets) {

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resource_group}/providers/Microsoft.ContainerRegistry/registries/{registry_name}/tasks/{task_name}?api-version=2019-04-01")

  # get token
  token <- getToken()

  # read body json
  data <- list(location = location,
               image_name = image_name,
               image_tag = image_tag,
               git_url = git_url,
               git_pat = git_pat,
               registry_name = registry_name,
               registry_user = secrets$user,
               registry_pass = secrets$pass
  )
  body <- fillJsonTemplate(file_name = "rest_body_acr_task.json",
                           data = data)

  # PUT call
  response <- httr::PUT(url = url,
                        add_headers(.headers = c(
                          "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                          ,"Content-Type" = "application/json")
                        ),
                        body = body,
                        encode = "json"
  )


  # parse response
  parsed_response <- content(response, "parsed")

  # check response
  if(parsed_response$properties$provisioningState == "Succeeded") {
    print(TRUE)
  } else {
    print(FALSE)
  }
}


## STEP 7 ##
#' create ACI
#'
#' deploys the Azure Container Instance (container groups)
#'
#' @param resource_group name of resource group
#' @param registry_name name of Azure Container Registry
#' @param container_name name of Azure Container Instance
createACI <- function(resource_group,
                      registry_name,
                      container_name) {

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resource_group}/providers/Microsoft.ContainerInstance/containerGroups/{container_name}?api-version=2018-10-01")

  # get token
  token <- getToken()

  # read body json
  data = list(location = location,
              image_name = image_name,
              image_tag = image_tag,
              container_name = container_name,
              registry_name = registry_name,
              container_cpu = container_cpu,
              container_memory = container_memory)
  body = fillJsonTemplate(file_name = "rest_body_aci.json",
                          data = data)

  # PUT call
  response <- httr::PUT(url = url,
                        add_headers(.headers = c(
                          "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                          ,"Content-Type" = "application/json")
                        ),
                        body = body,
                        encode = "json"
  )

  # parse response
  parsed_response <- content(response, "parsed")

  # check response
  if(parsed_response$properties$provisioningState == "Succeeded") {
    return(TRUE)
  } else {
    return(FALSE)
  }

}


## STEP 8 ##
#' start or stop ACI
#'
#' REST call for starting and stopping the container group
#'
#' @param resource_group name of resource group
#' @param container_name name of container group
#' @param action start or stop
manageACI <- function(resource_group,
                      container_name,
                      action = "stop") {

  # stop function if action is not stop or start
  if(action != "stop" && action != "start") {
    stop("action either has to be start or stop")
  }

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resource_group}/providers/Microsoft.ContainerInstance/containerGroups/{container_name}/{action}?api-version=2018-10-01")

  # get token
  token <- getToken()

  # POST call
  response <- httr::POST(url = url,
                         add_headers(.headers = c(
                           "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                           ,"Content-Type" = "application/json")
                         ),
                         encode = "json"
  )


  # parse response
  parsed_response <- content(response, "parsed")

}

#' POST REST call
#'
#' empty POST call template
#'
#' @param url the Azure REST endpoint (= URL)
#' @param body the json body for the REST call
#' @return the success message
makePOSTRestCall <- function(url, body = "") {

  # get token
  token <- getToken()

  # POST call
  response <- httr::POST(url = url,
                         add_headers(.headers = c(
                           "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                           ,"Content-Type" = "application/json")
                         ),
                         body = body,
                         encode = "json"
  )

  # ToDo: return the success message
  # check response
  if(parsed_response$properties$provisioningState == "Succeeded") {
    print(TRUE)
  } else {
    print(FALSE)
  }

  return(response)

}


#' PUT REST call
#'
#' empty PUT call template
#'
#' @param url the Azure REST endpoint (= URL)
#' @param body the json body for the REST call
#' @return the success message
makePUTRestCall <- function(url, body = "") {

  # get token
  token <- getToken()

  # POST call
  response <- httr::PUT(url = url,
                        add_headers(.headers = c(
                          "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                          ,"Content-Type" = "application/json")
                        ),
                        body = body,
                        encode = "json"
  )

  # ToDo: return the success message
  # check response
  if(parsed_response$properties$provisioningState == "Succeeded") {
    print(TRUE)
  } else {
    print(FALSE)
  }

  return(response)

}

#' GET REST call
#'
#' empty GET call template
#'
#' @param url the Azure REST endpoint (= URL)
#' @return the success message
makeGETRestCall <- function(url) {

  #get token
  token <- getToken()

  # POST call
  response <- httr::GET(url = url,
                        add_headers(.headers = c(
                          "Authorization" = paste0("Bearer ", token) # token$credentials$access_token)
                          ,"Content-Type" = "application/json")
                        ),
                        encode = "json"
  )

  # ToDo: return the success message
  # check response
  if(response$status_code == 200) {
    print(TRUE)
  } else {
    print(FALSE)
  }

  return(response)

}

#' Fillout json template
#'
#' needs a template and a list of variables that get filled into
#'
#' @param file_name name of the json file in the template folder
#' @param data list with variables to fill in
#' @return a rendered json object
fillJsonTemplate <- function(file_name = "json.json", data) {

  # library("rjson")
  # library("whisker")

  # data = list(country = "Villach")

  json_file <- file_name
  file_path <- file.path("templates", "rest", file_name)

  template <- paste(readLines(file_path), collapse="")

  processed <- whisker::whisker.render(template, data)

  json <- rjson::fromJSON(processed)

  return(json)
}

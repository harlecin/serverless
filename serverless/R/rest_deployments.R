library('httr')
library('rjson')
library('whisker')

runAll <- function() {
  subscription <- getUserInput("Azure Id Subscription");
  setAzureSub(subscription)

}

setAzureSub() {

}

#' runs eintire workflow
#'
#' runs everything
#' creates all necessary variables and calls all functions
runAll <- function() {

  loadConfig()
  checkConfig()

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
            container_name = container_name,
            env_data)

  manageACI(resource_group = resource_group,
            container_name = container_name,
            action = "stop")
}

#' loads config
#'
#' loads all necessary variables into global environment
#' ToDo: fix global environment
#' @export
loadConfig <- function() {

  # personal information
  # i.e. git_url, git_pat, Azure subscription
  source(file.path("R", "config.R"))

  # Azure
  app_name <<- "azure_mgmt"
  client_id <<- "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
  client_secret <<- NULL
  # subscription = "XXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

  # git
  # git_pat = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  # git_repo = "https://github.com/{user}/{repo}"

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
  env_name_1 <- "name1"
  env_value_1 <- "value1"
  env_name_2 <- "name2"
  env_value_2 <- "value2"
  env_set_1 <- list(env_name_1, env_value_1)
  env_set_2 <- list(env_name_2, env_value_2)
  env_data <<- list(env_set_1, env_set_2)
}

#' checks config variables
#'
#' checks the necessary config variables
#' @export
checkConfig <- function() {

  if(!exists(subscription)) {
    stop("Azure subscirption id is missing!")
  }

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
    print("Azure Container Registry successfully created.")
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
               registry_pass = secrets$pass)

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
#' @param container_cpu CPU cores
#' @param container_memory memory in RAM
#' @param env_data a list with environment variables
createACI <- function(resource_group,
                      registry_name,
                      container_name,
                      container_cpu = "1",
                      container_memory = "1",
                      env_data) {

  # REST url
  url <- glue::glue("https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resource_group}/providers/Microsoft.ContainerInstance/containerGroups/{container_name}?api-version=2018-10-01")

  # get token
  token <- getToken()

  # note for whiskers: use triple {{{}}} to prevent problems with quotes, i.e. html escaping
  if(exists("env_data")) {
    env_variables <- combineEnvironmentVariable(env_data)
  } else {
    env_variables = ""
  }

  # read body json
  data = list(location = location,
              image_name = image_name,
              image_tag = image_tag,
              container_name = container_name,
              registry_name = registry_name,
              container_cpu = container_cpu,
              container_memory = container_memory,
              env_variables = env_variables)
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

# ToDo: createLogicApp <- function()

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
fillJsonTemplate <- function(file_name, data) {

  # create platform-independant file path
  file_path <- file.path("templates", "rest", file_name)

  # read file as character
  template <- paste(readLines(file_path), collapse="")

  # fill out template with supplied data
  processed <- whisker::whisker.render(template, data)

  # convert to json
  json <- rjson::fromJSON(processed)

  return(json)
}


combineEnvironmentVariable <- function(env_data){

  # env_name_1 = "name1"
  # env_value_1 = "value1"
  # env_name_2 = "name2"
  # env_value_2 = "value2"
  #
  # set_1 = list(env_name_1, env_value_1)
  # set_2 = list(env_name_2, env_value_2)
  #
  # data <- list(set_1, set_2)

  # iterate over variables
  singles <- ""
  for(i in 1:length(env_data)) {
    singles[i] = createSingleEnvironmentVariable(env_data[[i]][[1]], env_data[[i]][[2]])
  }

  # create final string to add to REST call
  environment_variables = paste0(singles, collapse = ",")

  return(environment_variables)
}

createSingleEnvironmentVariable <- function(name, value){

  # data <- list(name = "sqlpass", value = "123abc")
  data <- list(name = name, value = value)

  template = "{
              \"name\": \"{{name}}\",
              \"value\": \"{{value}}\"
              }"

  string = whisker::whisker.render(template, data)
  return(string)
}


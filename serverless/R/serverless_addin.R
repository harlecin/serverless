#' This Addin creates an addin for RStudio that creates a dockerfile
#'
#' This will create a dockerfile which includs your R package.
serverless_addin <- function() {
  # path <- getPath()

  # not working if called from console
  # cat("package name: ",getPath(),"\n")

  cat("get package name...\n")
  package_name <- getUserInput("package name")

  cat("create dockerfile...\n")
  createDockerfile(package_name)

  cat("move dockerfile...\n")
  moveDockerfile()

  cat("build docker image locally... \n")
  buildDockerImage()

  cat("build docker image in ACR... \n")
  buildAcrImage()

}

#' Creates a dockerfile
#'
#' @param package_name The name of the package
#' @export
createDockerfile <- function(package_name = "package_name") {

  # gather parameter from user
  # r_version <- getUserCred("R Version")
  r_version <- "3.5.3"
  # package_name <- getPath()
  # package_name <- getUserCred("Package name")

  # write the file to disk
  sink(file = 'DOCKERFILE')

  cat("FROM rocker/rstudio:", r_version, " \n\n", sep = "")
  # cat("RUN Rscript -e 'print('Hello, world!') \n\n")

  cat("RUN mkdir -p /usr/src/app \n")
  cat("WORKDIR /usr/src/app \n\n")

  cat("COPY ",package_name," ./",package_name,"/ \n", sep = "")
  cat("WORKDIR /usr/src/app/",package_name," \n\n", sep = "")

  # ToDo: RUN Rscript -e "install.packages('PACKAGENAME')"

  sink()
}

#' Moves the dockerfile one folder level up
#'
#' Moves the dockerfile one folder level up in order to be have at the package source level

moveDockerfile <- function() {
  # you can replace "copy" with "move", or vice versa
  args <- c("/c", "move", "DOCKERFILE", "..\\" )
  system2("cmd", args)
}


#' Calls the \code{docker build} command with name and tag parameters
#' @export
buildDockerImage <- function() {

  # move one levels higher and call docker build
  args <- c("/c", "cd", "..", "&&", "docker build", "-t", "serverless:latest", ".")
  system2("cmd", args)

  # list build image
  args <- c("/c", "docker images serverless")
  system2("cmd", args = args)


  # build docker image
  # args <- c("/c", "docker build", "-t", "serverless:latest", "." )
  # args <- c("/c", "docker images")
  # system2("cmd", args = args)
}

#' Get user credentials via dialogue
#'
#' Opens a generic user dialogue to ask for credentials
#'
#' @param cred The name of the service.
#' @return user input, i.e. credential
getUserCred <- function(cred) {

  # probably completely unnecessary

  # user promt for Azure token
  token <- rstudioapi::askForPassword(
    prompt = paste("Please provide your", cred, "access token.")
  )

  return(token)
}

#' Get user input via dialogue
#'
#' Opens a generic user dialogue to ask for normal user input
#'
#' @param input user input specifications
#' @return user input, i.e. package name
#' @export
getUserInput <- function(input) {

  # probably completely unnecessary

  # user promt for Azure token
  user_input <- rstudioapi::showPrompt(
    title = "User Input", message = paste("Enter",input,"please."), default = ""
  )

  return(user_input)
}

#' Get user input from dropdown list via dialogue
#'
#' Opens a dropdown user dialogue to ask for user selection
#'
#' @param choice possible user choice as a vector
#' @param title title of dropdown choices
#' @return user input, i.e. chosen option
#' @export
getUserInputDropdown <- function(choice = c("choice A","choice B","choice C"), title = "resource") {

  i <- menu(choice, graphics=TRUE, title=paste("Choose",title))
  user_selection <- choice[i]

  return(user_selection)
}

#' Reads the content of the active R skript
readContent <- function() {

  # use rstudioapi to read the content of the file in which you are working
  script_content <- rstudioapi::getActiveDocumentContext()$content
  # print(contant[7])

  # write content to file
  sink(file = 'script.R')
  cat(script_content, sep = "\n")
}

#' Helpder function to get the Path of the current package
#' @return directory path of package
getPath <- function() {

  # use rstudioapi to read the path of the file in which you are working
  path_file <- rstudioapi::getActiveDocumentContext()$path
  dir <- dirname(path_file)

  # rstudioapi::getActiveDocumentContext()$path

  return(dir)
}

#' Helpder function to get the Path of the current package
#' @return directory path of package
#' @export
getPackageTitle <- function() {

  # use rstudioapi to read the path of the file in which you are working
  # path_file <- rstudioapi::getActiveDocumentContext()$path
  path_file <- getwd()
  dir <- dirname(path_file)
  package_tile <- regmatches(dir,regexpr("([^/]+$)", dir))
  return(package_tile)
}

#' Calls the \code{az acr build} command with name and tag parameters
#' @export
buildAcrImage <- function() {

  args <- c("/c", "az login")
  system2("cmd", args)

  acr_name = "dstest"
  image_name = "serverless"
  image_tag = "latest"

  args <- c("/c", "cd", "..", "&&", "az acr build", "--registry", acr_name, "--image", paste0(image_name, ":", image_tag), "." )
  system2("cmd", args)
}

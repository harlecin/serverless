#' This Addin creates an addin for RStudio that creates a dockerfile
#'
#' This will create a dockerfile which includs your R package.
serverless_addin <- function() {
  # path <- getPath()

  # not working if called from console
  # cat("package name: ",getPath(),"\n")

  print("get package name...\n")
  package_name <- getUserInput("package name")

  print("get script name...\n")
  script_name <- getUserInput("script name")

  print("create dockerfile...\n")
  createDockerfile(package_name, script_name)

  print("move dockerfile...\n")
  moveDockerfile()

  cat("build docker image locally... \n")
  buildDockerImage()

  cat("build docker image in ACR... \n")
  buildAcrImage()

}

#' Creates a dockerfile
#'
#' @param package_name name of the package
#' @param script_name name of your script to run the package
#' @export
createDockerfile <- function(package_name = "package_name",
                             script_name = "script_name") {

  # dependencies <- getDependencies(package_name)

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

  cat("RUN Rscript -e \"install.packages('",package_name,"')\"", sep = "")

  cat("CMD Rscript ",script_name,".R", sep = "")

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


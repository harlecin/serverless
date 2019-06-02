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
    title = "User Input", message = paste("Please enter your",input,":"), default = ""
  )

  return(user_input)
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
    prompt = paste("Please provide your", cred, ":")
  )

  return(token)
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

  i <- menu(choice, graphics=TRUE, title=paste("Please choose your preferred",title,":"))
  user_selection <- choice[i]

  return(user_selection)
}

#### HELPER FUNCTIONS ####

#' Helpder function to get the Path of the current package
#'
#' OBSOLETE?
#' @return directory path of package
#' @export
getPath <- function() {

  # use rstudioapi to read the path of the file in which you are working
  path_file <- rstudioapi::getActiveDocumentContext()$path
  dir <- dirname(path_file)

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

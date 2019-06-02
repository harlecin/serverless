#' Creates a dockerfile with or without user input
#'
#' @param get_user_input Will the user input all the specifications or should we use default ones
#' @export
dockerfile_template <- function(get_user_input = TRUE) {

  # read template
  template <- readLines("templates/dockerfile_general.txt")

  # get user inputs
  if(get_user_input == TRUE) {

    # we could make these lists dynamic but I think we would give the user too much choice and just confuse them
    rocker_image_choice <- c("rstudio", "tidyverse", "verse", "geospatial")
    rocker_image <- getUserInputDropdown(choice = rocker_image_choice, title = "Rocker Image")

    rocker_r_version_choice <- c("3.5.3", "3.4.4", "3.3.3")
    rocker_r_version <- getUserInputDropdown(choice = rocker_r_version_choice, title = "R Version")

    package_name = getUserInput(input = "package name")

  } else {

    # standard input
    rocker_image = "rstudio"
    rocker_r_version = "3.5.3"
    package_name = getPackageTitle()
  }

  # combine template and input
  data <- list( rocker_image = rocker_image,
                rocker_r_version = rocker_r_version,
                package_name = package_name
  )

  dockerfile_content <- whisker.render(template, data)

  return(dockerfile_content)
}

#' Creates a tmp directory and saves dockerfile there
#'
#' @param dockerfile_content content of dockerfile
#' @param folder_name the folder in which the file is saved
#' @usage create_tmp_and_dockerfile(dockerfile_content)
#' @export
create_tmp_and_dockerfile <- function(dockerfile_content, folder_name = "tmp") {

  # create tmp directory
  path_current <- getwd()
  new_folder <- "tmp"
  dir.create(file.path(path_current, new_folder))
  setwd(file.path(path_current, new_folder))

  # write to file
  sink(file = "DOCKERFILE")
  cat(dockerfile_content)
  sink()

  # reset working directory
  setwd(path_file)
}

#' Deletes a directory and its content
#'
#' @param folder_name the folder to delete
#' @export
delete_tmp_folder <- function(folder_name = "tmp") {
  path_current <- getwd()
  unlink(file.path(path_current, folder_name), recursive = TRUE)
}

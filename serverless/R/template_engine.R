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
    rocker_version = "3.5.3"
    package_name = getPackageTitle()
  }

  # combine template and input
  data <- list( rocker_image = rocker_image,
                rocker_r_version = rocker_r_version,
                package_name = package_name
  )

  text <- whisker.render(template, data)

  # write to file
  sink(file = 'DOCKERFILE')
  cat(text)
  sink()

}

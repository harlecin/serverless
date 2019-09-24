test_that("JSON templates are correctly filled",{

  # create result
  result = list("location" = "westeurope",
                "sku" = list("name" = "Basic"))

  # prepare function call
  data = list(location = "westeurope",
              sku = "Basic")
  body = fillJsonTemplate(file_name = "test_that.json",# file.path("tests", "testthat", "test_that.json"),
                          data = data)

  expect_equal(body, result)
})

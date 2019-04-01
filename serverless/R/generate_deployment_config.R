#' Generate config file
#'
#' Generates a config file in current working directory to specify which services
#' should be created and deployed
#'
#' @param name Service name
#' @param provider Cloud service provider to use. Currently supported "azure"
#' @import yaml
generate_deployment_config = function(name, provider, type='container') {

  if (type == 'container') {
      yaml::write_yaml(list(name = name,
                         provider = provider,
                         services = list(compute = 'aci',
                                         registry = 'acr',
                                         trigger = 'http'
                                         )
                         ),
                       file = "./serverless.yaml",
                       indent = 2)
  }

}

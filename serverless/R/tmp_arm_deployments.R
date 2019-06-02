library(httr)
library(AzureRMR)

# Your tenant_id/directory_id -> azure portal/azure active directory/Properties/directory id
tenant_id = ""

# azure subscription -> azure portal/subscriptions
subscription = ""

resource_group = "serverless"
location = "westeurope"


az = create_azure_login(tenant = tenant_id)

sub = az$get_subscription(subscription)

## Maybe deploy a template instead with rg$deploy_template?
sub$create_resource_group(resource_group, location)

## Create ACR using template
rg = sub$get_resource_group(resource_group)

registry_name = "acrserverlesstest"

## ACI parameters
parameters = list(
  registryName = registry_name,
  registryLocation = location,
  registrySKU = "Basic",
  adminUserEnabled = FALSE
)

## Why is the parameters.json template not working?
tpl = rg$deploy_template(name = "ACR",
                         template = "../../data/az-templates/acr-templates/template.json",
                         parameters = parameters
)

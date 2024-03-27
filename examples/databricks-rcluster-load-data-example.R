# Title: Example for using SparkR using SAS tokens to authenticate with analytical/data lakes on Databricks
# Author: Edmund Haacke
# Date Created: 2023-10-13
# Date Modified: 2024-03-27
# Description:
#   The R cluster does not support passthrough authentication, unlike those aimed at python workflows.
#   This example shows how to use SAS tokens stored in Azure Key Vault to achieve this. This solution
#   formerly depended on the older WASBS driver, due to an authentication issue using the ABFSS driver
#   with ADLS Gen2 storage. As per Microsoft Support, this is due to an initial HEAD request to the
#   root container to check whether hierarchical namespace (HNS) is enabled or not, which fails due to
#   SAS token giving directory level permissions. By setting the spark conf setting 'fs.azure.account.hns.enabled'
#   to 'true' or 'false' (depending on whether HNS is enabled or not) avoids this HEAD request. This then
#   allows the use of the current ABFSS driver. Credit to Microsoft and David Green for the solution.
#   Tested on the Analytical Lake and Data Lake.

# >>>> installations <<<<
install.packages(c("AzureAuth", "AzureKeyVault"))

# >>>> constants <<<<
# specify the full address for the azure key vault
KEY_VAULT_ADDR <- "https://<insert>.vault.azure.net"

# >>>> functions <<<<
# this function will setup the current spark session configuration with the relevant SAS tokens. note that although
# in theory you can specify multiple SAS tokens across different containers // accounts, because the SAS tokens in 
# the setup are not at the container level, this function will need rerunning to update the spark session every time
# a new SAS token is pulled
set_spark_config_for_acc_and_cont <- function(
  account, container, sas_secret, hns_enabled=TRUE
){
  # list to store spark configuration elements
  spark_config <- list()
  spark_config[[paste0("fs.azure.account.hns.enabled")]] = ifelse(hns_enabled, "true", "false");
  spark_config[[paste0("fs.azure.account.auth.type.",account,".dfs.core.windows.net")]] = "SAS"
  spark_config[[paste0("fs.azure.sas.token.provider.type.",account,".dfs.core.windows.net")]]="org.apache.hadoop.fs.azurebfs.sas.FixedSASTokenProvider"
  spark_config[[paste0("fs.azure.sas.fixed.token.",account,".dfs.core.windows.net")]] = sprintf("%s", sas_secret$value)
  spark_config[[paste0("fs.azure.sas.",container,".",account,".dfs.core.windows.net")]] = sprintf("%s", sas_secret$value)
  # update the current Spark session
  SparkR::sparkR.session(master="local[*]", sparkConfig=spark_config)
}

# >>>> retrieve SAS token <<<<
# login using device_code flow - open the link and type the code (nb uses Azure CLI app ID)
token <- AzureAuth::get_azure_token(
  resource="https://vault.azure.net", tenant="common", app="04b07795-8ddb-461a-bbee-02f9e1bf7b46",
  auth_type="device_code"
)
# the azure key vault with all the SAS tokens
vault <- AzureKeyVault::key_vault(KEY_VAULT_ADDR, token=token)

# ---- Accessing Data ----
# Rerun all of the following code every time using a different token.

# load an SAS token using the naming structure mentioned...
sus_sas <- vault$secrets$get("<INSERT HERE>")

# >>>> key vars <<<<
# specify the account...
clp_account <- "<ACCOUNT>"
# specify the container name...
clp_cont <- "<CONTAINER>"
# the relative path to the data...
clp_rel_path <- "<RELATIVE PATH>"
# setup the full path to the data
data_path <- sprintf("abfss://%s@%s.dfs.core.windows.net/%s/", clp_cont, clp_account, clp_rel_path)
# setup spark with the SAS token for the above data
set_spark_config_for_acc_and_cont(
  account=clp_account, container=clp_cont, sas_secret=sus_sas
)
# >>>> load data <<<<
print(data_path)
# load data using SparkR
df <- SparkR::read.parquet(data_path)
display(df)

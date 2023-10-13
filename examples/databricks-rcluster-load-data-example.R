# Title: Example for using SparkR using SAS tokens to authenticate with analytical/data lakes on Databricks
# Author: Edmund Haacke
# Date Created: 2023-10-13
# Description:
#   The R cluster does not support passthrough authentication, unlike those aimed at python workflows.
#   This example shows how to use SAS tokens stored in Azure Key Vault to achieve this. Note that unfortunately
#   this approach relies on the older wasbs driver rather than the newer abfss drivers, and it should be noted
#   that although this approach works with the ADLS Gen2 containers - the wasbs driver is in a deprecated state.
#   Tested on both analytical and data lake.

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
  account, container, sas_secret
){
  # list to store spark configuration elements
  spark_config <- list()
  spark_config[[paste0("fs.azure.account.auth.type.",account,".blob.core.windows.net")]] = "SAS"
  spark_config[[paste0("fs.azure.sas.token.provider.type.",account,".blob.core.windows.net")]]="org.apache.hadoop.fs.azurebfs.sas.FixedSASTokenProvider"
  spark_config[[paste0("fs.azure.sas.fixed.token.",account,".blob.core.windows.net")]] = sprintf("%s", sas_secret$value)
  spark_config[[paste0("fs.azure.sas.",container,".",account,".blob.core.windows.net")]] = sprintf("%s", sas_secret$value)
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
data_path <- sprintf("wasbs://%s@%s.blob.core.windows.net/%s/", clp_cont, clp_account, clp_rel_path)
# setup spark with the SAS token for the above data
set_spark_config_for_acc_and_cont(
  account=clp_account, container=clp_cont, sas_secret=sus_sas
)
# >>>> load data <<<<
print(data_path)
# load data using SparkR
df <- SparkR::read.parquet(data_path)
display(df)

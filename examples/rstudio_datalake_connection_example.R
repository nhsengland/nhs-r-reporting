# Title: Example for using SAS tokens to authenticate with analytical/data lakes on RStudio
# Author: David Savage/Miles Flitton
# Date Created: 2023-10-13
# Description:
#   Some workflows may require connecting to the Azure data lakes from RStudio, for example 
#   one may process large amounts of data in Databricks but have legacy code in RStudio for
#   outputs. This example shows how one can connect RStudio to the data lakes and read data
#   into RStudio for further analysis.


#Load libraries
install.packages("AzureStor", "AzureKeyVault", "arrow", "data.table")
library(AzureStor)
library(AzureKeyVault)
library(arrow)
library(data.table)


### Set up access settings

#Get Shared Access Signature auth for data
#Opens an interactive Azure authentication flow in your browser
vault <- key_vault("<KEY_VAULT_ADDR>")

### Read from specific lake area

#Gets the SAS for the relevant data - r = read access, w = write access
dfSAS <- vault$secrets$get("<INSERT_HERE>")

#Set connection settings
dl_endp <- storage_endpoint("<STORAGE_ADDRESS>", sas = dfSAS$value )
cont <- storage_container(dl_endp, "<CONTAINER>")
list_adls_files(cont, dir = "/<PATH>/", info = c("all", "name"), recursive = FALSE)

#Read data
filename <- "PATH/TO/.parquet"
rawdata <- storage_download(cont, filename, dest = NULL)
parq_df <- read_parquet(rawdata)

#Read data recursively
filenames <- c("PATH/TO/.parquet1",
               "PATH/TO/.parquet2")
multiparq_df <- rbindlist(lapply(filenames, function(i){
  rawdata <- storage_download(cont, i, dest = NULL)
  read_parquet(rawdata)
}))

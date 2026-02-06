# Written to execute Ameriflux QAQC
# By Sara Knox
# Mar 6, 2025
#
# Last modification: Nov 6, 2022 (Zoran)
#
# Example (it should be entered as one line if a Win CMD prompt) :
#   "C:\Program Files\R\R-4.2.1\bin\Rscript.exe" "C:/Biomet.net/R/database_functions/Run_ThirdStage_REddyProc.R" "C:/Biomet.net/R/database_functions" "p:\database\Calculation_Procedures\TraceAnalysis_ini\DSM\log\DSM_setThirdStageCleaningParameters.R"  2> "p:/database/Calculation_Procedures/TraceAnalysis_ini/DSM/log/DSM_ThirdStageCleaning.log" 1>&2
# Calling it from R-Studio:
#   args <- c("C:/Biomet.net/R/database_functions", "p:/database/Calculation_procedures/TraceAnalysis_ini/DSM/log/DSM_setThirdStageCleaningParameters.R")
#   source("C:/Biomet.net/R/database_functions/Run_ThirdStage_REddyProc.R")


if(length(commandArgs(trailingOnly = TRUE))==0){
  cat("\nIn: amf_chk_run:\nNo input parameters!\nUsing whatever is in args variable \n")
} else {
  # otherwise set args to commandArgs()
  args 		<- commandArgs(trailingOnly = TRUE)
}

fx_path   		<- args[1]

# run qaqc main
source(file.path(fx_path,'R','amfqaqc_main.R'))

cat("=============================================================================\n")
cat(" Warnings\n")
cat("=============================================================================\n")
warnings()
cat("=============================================================================\n\n")
cat("End of amf_chk_run.\n\n")





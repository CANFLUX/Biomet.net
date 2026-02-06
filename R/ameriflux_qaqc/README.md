# amerifluxqaqc

An R programmatic interface to perform AmeriFlux 
[Data QA/QC](https://ameriflux.lbl.gov/data/flux-data-products/data-qaqc/). 
The original and operational Data QA/QC pipeline was developed in Python by the
AmeriFlux Management Project ([See GitRepo](https://github.com/AMF-FLX/AMF-BASE-QAQC))
This code base mimics the functionality and adopts similar algorithms. See a
[general overview](https://ameriflux.lbl.gov/data/flux-data-products/data-qaqc/)
of the Data QA/QC. In addition, this code base include prototype checks that 
are under development. For methodological details, please refer to the following 
paper and technical note:

  - Chu, H., Christianson, D.S., Cheah, YW. et al. AmeriFlux BASE data pipeline
  to support network growth and data sharing. Sci Data 10, 614 (2023).
  https://doi.org/10.1038/s41597-023-02531-2 
  - Chu, H., Christianson, D.S., Cheah, YW. et al. Technical Note: AmeriFlux 
  BASE Flux/Met Data QA/QC. AmeriFlux Management Project (2023)
  [link](https://docs.google.com/document/d/1mlpwP9Ajutxav9FfyhGWslTrpHewDLGkVoEgVSJscLA/export?format=pdf)
  

## Functionality

Data QA/QC assesses units and sign conventions, timestamp alignments, trends,
step changes, outliers based on site-specific historical ranges, multivariate 
comparisons, diurnal/seasonal patterns, USTAR (i.e., friction velocity) 
filtering, and variable availability. Current package contains the following
test modules:

  - Timestamp Alignment
  - Physical Range
  - Multivariate Comparison
  - Seasonal-Diurnal Pattern
  - USTAR Filtering
  - Variable Coverage
    - All Empty Variable
    - Mandatory Variable
  - Inter-Quantile Variation (prototype)
  - Sign Convention (prototype)
  - Wind Sigma (prototype) 
  - Unit Check (prototype)

***Disclaimer:** The codes mimic the functionality and adopt similar algorithms 
based on the Data QAQC pipeline developed and operated by the AmeriFlux 
Management Project. However, the output (e.g., figure style, statistics) may 
differ slightly due to code implementation and environment.*  
  
## To Run

  - **Download the repository** to a desired local directory
    - This is the working directory & how you define *path* in *amfqaqc_main.R*
    - If non-existed, create an \\output\\ folder under this directory 
  - **Create a \\QAQCcombined\\ folder** in your desired location
    - This is the data folder & how you define *path0* in *amfqaqc_main.R*
  - **Format your data properly** and **put them in the \\QAQCcombined\\ folder**
    - For demonstration, a \\QAQCcombined\\ folder with example files are included
    in the \\data\\ folder.
    - Files must use the following filename convention:
      - {SITE_ID}\_\{RESOLUTION}\_\{TIMESTAMP_START}\_\{TIMESTAMP_END}\-\{CREATION_TIME}.csv
        - {SITE_ID}: AmeriFlux Site ID in the form of CC-Sss.
        - {RESOLUTION}: Data time interval, HH for half-hourly or HR for hourly
        - {TIMESTAMP_START}: The beginning timestamp for the first data row in 
        the format of YYYYMMDDHHMM.
        - {TIMESTAMP_END}: The ending timestamp for the last data row in the 
        format of YYYYMMDDHHMM.
        - {CREATION_TIME}: The creation timestamp of the file in the format of 
        YYYYMMDDHHMM.
        - For example, US-CRT_HH_201101010000_201401010000-202411121200.csv
      - Multiple files per site can coexist. The QAQC workflow always runs the 
      latest created files for each site.
      - Check AmeriFlux 
      [website](https://ameriflux.lbl.gov/data/uploading-half-hourly-hourly-data/)
      for additional guidelines of the file format and variable names/units. 
  - **Open \\R\\amfqaqc_main.R**
    - This is the main workflow to run QAQC.
    - Change *path* and *path0* as described above.
    - Specify *target.site* with target AmeriFlux Site ID (CC-Sss) (character). 
    The workflow only runs files with *SITE_ID* included in *target.site*. It 
    can be a single site (string) or multiple sites (vector).  
      - Example: *target.site <- "US-UTW"*
      - Example: *target.site <- c("US-UTW", "US-UUC", "US-Ro5", "US-Los")*
      - Set *target.site <- "All"* to run all sites in the folder.
    - Modify the following control parameters as desired (True/False).
      - *sink.to.log*: Whether output QAQC log to a text file (True/False).
      - *check.last.year.only*: Whether run QAQC only for the last X years 
      (True/False).
      - *check.multivarite.all.year*: Whether run multivariate check for all 
      years (True/False).
      - *output.stat* Whether output summary statistics in csv files (True/False).
      - *plot.always* Whether plot figures always (True/False). If False, it 
      outputs figures only when there are errors or warnings in a check. 
    - Config whether to run each QAQC module (True/False).
      - *run.var.coverage*: Variable Coverage
      - *run.diurnalseasonal*: Diurnal-Seasonal Pattern
      - *run.physical*: Physical Range
      - *run.iqr*: Inter-Quantile Variation
      - *run.ustar*: USTAR Filtering
      - *run.timestamp*: Timestamp Alignment
      - *run.ratio*: Ratio-Percentage
      - *run.multivariate*: Multivariate Comparison
      - *run.sigmaw*: Wind Sigma
      - *run.sign*: Sign Convention
      - *run.unit*: Unit Check
      - *run.vpd*: VPD Unit Check
      - *run.empty.var*: All Empty Variable
      - *run.mandatory.var*: Mandatory Variable
  - **Run the entire amfqaqc_main.R** 
  - Once finished, check **output files under the \\output\\ folder**
    - Depending on config, the output may contain following types of files:
      - Figures: Self-explanatory figures with summary messages
      - CSV files: Summary statistics determine the results of each check.
      See Technical Note above for details.
      - Log file: A text file summarizes the high-level results of QAQC. If 
      *sink.to.log = False*, the summary will returned in R Console directly.
        
## Citation

Chu, H., Christianson, D.S., Cheah, YW. et al. AmeriFlux BASE data pipeline to 
support network growth and data sharing. Sci Data 10, 614 (2023). 
https://doi.org/10.1038/s41597-023-02531-2

## Acknowledgement

This package was supported in part by funding provided to the
AmeriFlux Management Project by the U.S. Department of Energy’s
Office of Science under Contract No. DE-AC0205CH11231.

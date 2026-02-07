# Note: 1. IQR variability check trigger lots of false warning, consider turning
#          it off if diurnal-seasonal in place
#       2. Sites with dampened/all positive G trigger waning in sign check
#       3. To-Do: Add prevailing WD check
#
#
################################################################################
#### Load required library

require("zoo")
require("httr")
require("jsonlite")
require("lmodel2")
require("amerifluxr")
require("pracma")
require("colorspace")

# Package names
packages <- c("zoo", "httr", "jsonlite", "lmodel2", "pracma", "colorspace", "devtools")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages],repos="https://cloud.r-project.org")
}


# amerifluxr no longer available on cran. Installing amerifluxr requires 'devtools'
packages <- "amerifluxr"

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (installed_packages == FALSE) {
  devtools::install_github("chuhousen/amerifluxr")
}

################################################################################
#### Data directory
##   Change path0 to where the data files are located
##   Put data files in path0 under the QAQCcombined\\ directory
#path0 <- "D:\\AmeriFlux-Data\\00_olaf_data_ameriflux\\"
path0 <- args[2]
comb.in <- file.path(path0, "QAQC")
out.dir <- file.path(comb.in, "output")
#### Working directory
##   Change path to where the R project is located
path <- args[1]
work.dir <- file.path(path, "R")
utils.dir <- file.path(path, "utils")
seasonal.dir <- file.path(path, "data","diurnal-seasonality")
kdf.dir <- file.path(path, "data","variable-kernel-density")
path_temp <- args[4]
temp.dir <- file.path(path_temp,"temp")

################################################################################
#### Load required functions
source(file.path(work.dir, "amf_chk_constant.R"))
#source(file.path(work.dir, "amf_chk_all_missing.R"))
source(file.path(work.dir, "amf_chk_diurnal_seasonal.R"))
source(file.path(work.dir, "amf_chk_sigma.R"))
source(file.path(work.dir, "amf_chk_timestamp_alignment.R"))
source(file.path(work.dir, "amf_chk_sign.R"))
source(file.path(work.dir, "amf_chk_vpd.R"))
source(file.path(work.dir, "amf_chk_ustar_filter.R"))
source(file.path(work.dir, "amf_chk_multivar.R"))
source(file.path(work.dir, "amf_chk_multivar_multiyear.R"))
source(file.path(work.dir, "amf_chk_physical_range.R"))
source(file.path(work.dir, "amf_chk_var_coverage.R"))
source(file.path(work.dir, "helper_functions.R"))
source(file.path(work.dir, "zzz.R"))

################################################################################
#### Control QA/QC run
##   Edit the following to control the QAQC workflow

## target sites, case sensitive
# use "all" if running all sites in the directory
target.site <- args[3]

## Whether output QAQC log
# Set False to return directly to console
sink.to.log <- T

## Whether run QAQC only for the last X years in the data file
# Set False to run entire record
# Use check.years to set the X year
check.last.year.only <- F
#check.years <- 5

## Whether run multivariate check for all years
#  Set True to scan deviation in slopes
check.multivarite.all.year <- T

## QAQC output setup
output.stat <- F # whether output summary statistics in csv files
plot.always <- T # whether plot figures always
# If set False, only plot when fail/warning

## config whether to run each QAQC module
run.var.coverage <- T
run.diurnalseasonal <- T
run.physical <- T
run.iqr <- T # inter-quantile range check
run.ustar <- T
run.timestamp <- T
run.ratio <- T
run.multivariate <- T
run.sigmaw <- T
run.sign <- T
run.unit <- T
run.vpd <- T
run.empty.var <- T
run.mandatory.var <- T

################################################################################
#### Setup & metadata for QAQC run
##   Do not modify unless really necessarily
## get config information
amf_cfg <- amf_qaqc_config()

## physical limit
FP_ls <- amerifluxr::amf_variables()
FP_ls$Max_buff <-
  FP_ls$Max + amf_cfg$buffer.precentage * (FP_ls$Max - FP_ls$Min)
FP_ls$Min_buff <-
  FP_ls$Min - amf_cfg$buffer.precentage * (FP_ls$Max - FP_ls$Min)
FP_ls$Range <- FP_ls$Max - FP_ls$Min

## variable variability
FP_iqr <-
  read.csv(file.path(kdf.dir, "AMF_fullsite_FPvar_limit_IQR.csv"),
           header = TRUE)

FP_ls <- merge.data.frame(FP_ls,
                          FP_iqr,
                          by.x = "Name",
                          by.y = "Variable",
                          all.x = TRUE)
## Sign convention
sign.var.ls <- amf_cfg$sign.var.ls
sign.var.prototype <- list()

sign.var.prototype[[1]] <-
  read.csv(file.path(seasonal.dir, amf_cfg$threshold.ver,
                     "ALL_BASE_sign_convention_prototype.csv"),
           header = T)
id3 <- rep(seq(1, 24), each = 2)
sign.var.prototype.tmp <-
  data.frame(HR2 = tapply(sign.var.prototype[[1]]$HR2, id3, mean))
for (pp in 2:ncol(sign.var.prototype[[1]])) {
  sign.var.prototype.tmp <- cbind.data.frame(sign.var.prototype.tmp,
                                             tmp = tapply(sign.var.prototype[[1]][, pp], id3, mean))
  colnames(sign.var.prototype.tmp)[which(colnames(sign.var.prototype.tmp) == "tmp")] <-
    colnames(sign.var.prototype[[1]])[pp]
}
sign.var.prototype[[2]] <- sign.var.prototype.tmp

## Site general information
sgi.ameriflux <- amerifluxr::amf_site_info()[, c("SITE_ID",
                                                 "LOCATION_LAT",
                                                 "LOCATION_LONG")]
#browser()

sgi.ameriflux <-
  sgi.ameriflux[which(sgi.ameriflux$SITE_ID %in% target.site),]
# In the case of a new site:
if (nrow(sgi.ameriflux)==0) {
  sgi.ameriflux[1,1]<-target.site
  sgi.ameriflux[1,2]<-as.numeric(args[5])
  sgi.ameriflux[1,3]<-as.numeric(args[6])
  sgi.ameriflux$UTC_OFFSET <- NA
  sgi.ameriflux[1,4]<-as.numeric(args[7])
} else {
  sgi.ameriflux$UTC_OFFSET <- NA
  for (j in 1:nrow(sgi.ameriflux)) {
    sgi.ameriflux$UTC_OFFSET[j] <- amf_get_utc(sgi.ameriflux$SITE_ID[j])
  }
}


sgi.ameriflux$LOCATION_LAT <-
  format(round(as.numeric(sgi.ameriflux$LOCATION_LAT), digits = 6), nsmall = 6)
sgi.ameriflux$LOCATION_LONG <-
  format(round(as.numeric(sgi.ameriflux$LOCATION_LONG), digits = 6), nsmall = 6)


################################################################################
#### Prepare Data I/O folders, logs
# If no QAQC folder exists yet (e.g., first run)
if (!dir.exists(file.path(comb.in))){
  dir.create(file.path(comb.in))
}

# If no output folder exists yet (e.g., first run)
if (!dir.exists(file.path(out.dir))){
  dir.create(file.path(out.dir))
}

# If no temp folder exists yet (e.g., first run)
if (!dir.exists(file.path(temp.dir))){
  dir.create(file.path(temp.dir))
}

check.ver <- gsub("[-: ]" , "", substr(Sys.time(), 1, 19))
if (!dir.exists(file.path(out.dir, check.ver))){
  dir.create(file.path(out.dir, check.ver))
}

path.out <- file.path(out.dir, check.ver)

## list of data files
comb.list.in <- list.files(args[2], ".csv")
if (length(target.site) == 1 & target.site[1] == "all"){
  target.site <- unique(substr(comb.list.in, 1, 6))
}

## prepare check log
if (sink.to.log) {
  sink(paste0(file.path(
    path.out,
    check.ver),
    "_check_log.txt")
  )
}

################################################################################
####
#### Main workflow for looping through target sites - set up for only one site currently
####
################################################################################
for (i1 in 1:length(target.site)) {
  site <- target.site[i1]

  print(paste("################################################"))
  print(paste("######  ", target.site[i1], "  ##############################"))

  # ## locate the latest Combined file
  comb.list.tmp <-
     comb.list.in#[which(substr(comb.list.in, start = 1, stop = 6) ==
  #                        target.site[i1])]
  # #comb.list.tmp <- comb.list.tmp[nchar(comb.list.tmp) - 4 == 48]
  #
  # ## need to handle unexpected file name length (_OPTIONAL)
  # target.comb.ver <-
  #   as.numeric(substr(comb.list.tmp, start = 37, stop = 48))[
  #     which(as.numeric(substr(comb.list.tmp, start = 37, stop = 48)) ==
  #             max(as.numeric(substr(comb.list.tmp, start = 37, stop = 48))))]

  comb.list <-
    comb.list.tmp

  ## parse time resolution from filename
  target.res <- substr(comb.list, 8, 9)
  if(!target.res %in% c("HH", "HR")){
    target.res <- "HH"
    print(paste0(
      "[Warning] Cannot parse time resolution from filename, treat as HH"
    ))
  }
  d.hr <- ifelse(target.res == "HR", 24, 48)
  hr <- ifelse(d.hr == 48, 30, 60)

  ## read in latest combined QAQC file
  data1 <- read.csv(
    file.path(args[2], comb.list[1]),
    na.string = amf_cfg$na.alias,
    header = T,
    skip = 0,
    strip.white = TRUE,
    stringsAsFactors = F
  )

  ## parse timestamps
  TIMESTAMP <-
    strptime(data1$TIMESTAMP_START, format = "%Y%m%d%H%M", tz = "UTC")
  TIMESTAMP <-
    strptime(TIMESTAMP + 0.5 * hr * 60, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")

  ## Scan file for unexpected column format
  for (ll in 3:ncol(data1)) {
    ## check for infinite
    if (!is.numeric(data1[, ll]) &
        sum.notna(data1[, ll]) > 0) {
      print(paste(
        "[Warning]:",
        colnames(data1)[ll],
        "is not numeric, forced it to. Check if contain unrecognized strings."
      ))
      data1[, ll] <- as.numeric(paste(data1[, ll]))
    }
  }

  ##############################################################################
  ## Check variable-specific data coverage
  basename_work <- amerifluxr::amf_parse_basename(colnames(data1),
                                                  FP_ls = FP_ls$Name,
                                                  gapfill_postfix = "_F")

  var.year.comb <- amf_chk_var_coverage(
    site = target.site[i1],
    data.in = data1[,-c(1:2)],
    TIMESTAMP = TIMESTAMP,
    year.i = 1990,
    year.f = as.numeric(substr(Sys.Date(), 1, 4)),
    path.out = path.out,
    res = target.res,
    #file.ver = paste0(target.comb.ver),
    plot.always = run.var.coverage
  )[[1]]

  ##############################################################################
  ## obtain a list of target years (used in all later checks)
  scan.fullyear <- scan.year <- var.year.comb$year
  if (check.last.year.only) {
    scan.year <-
      scan.year[max(c(1, length(scan.year) - check.years + 1)):length(scan.year)]
    scan.fullyear <- scan.year
  }

  ## skip years if all variables have less than 10% data
  scan.year <-
    scan.year[scan.year %in% var.year.comb$year[
      apply(var.year.comb[,-c(1:5)], 1, max) > amf_cfg$min.data.to.check]]

  ## grab years with full record
  scan.fullyear <-
    scan.year[scan.year %in% var.year.comb$year[which(var.year.comb$full.year)]]

  ##############################################################################
  ## check empty columns
  if (run.empty.var) {
    ## look for all empty columns
    all.empty <- which(apply(var.year.comb[,-c(1:5)], 2, sum) == 0)
    if (length(all.empty) > 0)
      print(paste("[Info] All empty columns:", paste(
        colnames(var.year.comb[,-c(1:5)])[all.empty], collapse = ", "
      )))

    ## look for empty var-year
    for (vv in 6:ncol(var.year.comb)) {
      empty.var.year <-
        var.year.comb$year[which(var.year.comb[
          var.year.comb$year %in% scan.year, vv] == 0)]
      empty.var.year <-
        empty.var.year[empty.var.year %in% scan.year]

      if(length(empty.var.year) > 0 &
         !colnames(var.year.comb)[vv] %in% all.empty)
        print(paste("[Info] Empty variable-year:",
                    colnames(var.year.comb)[vv],
                    paste(empty.var.year, collapse = ", ")))
    }
  }

  ##############################################################################
  ## check presence of mandatory variables
  if (run.mandatory.var) {
    miss.mad.var <-
      amf_cfg$mad.var[which(!amf_cfg$mad.var %in%
                              basename_work$basename[!basename_work$is_gapfill])]
    for (mm in 1:length(amf_cfg$mad.opt.var)) {
      get.mad.opt.var <-
        which(amf_cfg$mad.opt.var[[mm]] %in%
                basename_work$basename[!basename_work$is_gapfill])
      if (length(get.mad.opt.var) == 0)
        miss.mad.var <- c(miss.mad.var, amf_cfg$mad.opt.var[[mm]][1])
    }
    if (length(miss.mad.var) > 0)
      print(paste(
        "[Warning] Missing mandatory variable:",
        paste(miss.mad.var, collapse = ", ")
      ))
  }

  ##############################################################################
  ## Generate SW_IN_POT
  if (length(sgi.ameriflux$LOCATION_LAT[grep(site, sgi.ameriflux$SITE_ID)]) > 0 &
      length(sgi.ameriflux$LOCATION_LONG[grep(site, sgi.ameriflux$SITE_ID)]) > 0 &
      length(sgi.ameriflux$UTC_OFFSET[grep(site, sgi.ameriflux$SITE_ID)]) > 0 &
      length(scan.year) > 0) {

    SW_IN_POT <- list()

    # Check OS
    sys_name <- Sys.info()["sysname"]
    if (sys_name == "Darwin") {
      sw_in_OS <- "sw_in_pot_mac64_multi"
    } else if (sys_name == "Windows") {
      sw_in_OS <- "sw_in_pot_win32_multi.exe"
    }
    #browser()
    for (ii in 1:length(scan.year)) {
      suppressMessages((system(
        paste(
          shQuote(file.path(utils.dir, sw_in_OS)),
          shQuote(file.path(temp.dir, site)),
          scan.year[ii],
          as.numeric(sgi.ameriflux$LOCATION_LAT[
            grep(site, sgi.ameriflux$SITE_ID)][1]),
          as.numeric(sgi.ameriflux$LOCATION_LONG[
            grep(site, sgi.ameriflux$SITE_ID)[1]]),
          sgi.ameriflux$UTC_OFFSET[
            grep(site, sgi.ameriflux$SITE_ID)][1]
        ),
        show.output.on.console = FALSE
      )))

      SW_IN_POT.tmp <-
        read.csv(file.path(temp.dir, paste0(site, "_", scan.year[ii], ".csv")),
          header = T)

      ## read in SW_IN_POT, aggregate for HR files
      if (target.res == "HR") {
        id <- rep(c(1, 2), nrow(SW_IN_POT.tmp) / 2)
        id2 <- rep(seq(1, nrow(SW_IN_POT.tmp) / 2), each = 2)
        SW_IN_POT[[ii]] <-
          data.frame(
            TIMESTAMP_START = SW_IN_POT.tmp$TIMESTAMP_START[id == 1],
            TIMESTAMP_END = SW_IN_POT.tmp$TIMESTAMP_END[id == 2],
            SW_IN_POT = tapply(SW_IN_POT.tmp$SW_IN_POT, id2, mean)
          )
      } else{
        SW_IN_POT[[ii]] <- SW_IN_POT.tmp
      }
    }

  } else{
    print(paste("[Info] Missing required metadata for SW_IN_POT"))
    SW_IN_POT <- NULL
  }

  ##############################################################################
  ## Physical limit check
  if (run.physical &
      length(scan.year) > 0) {
    ## identify list of variables
    check.limit.grab <-
      basename_work$variable_name[
        which(basename_work$basename %in%
                FP_ls$Name[!is.na(FP_ls$Min) & !is.na(FP_ls$Max)])]
    check.limit.grab.basename <-
      basename_work$basename[
        which(basename_work$basename %in%
                FP_ls$Name[!is.na(FP_ls$Min) & !is.na(FP_ls$Max)])]
    physical.stat.all <- NULL

    ## scan through variables & years
    for (j1 in 1:length(check.limit.grab)) {
      for (j2 in 1:length(scan.year)) {
        data1.tmp <-
          data1[which(TIMESTAMP$year + 1900 == scan.year[j2]),
                check.limit.grab[j1]]

        if (sum.notna(data1.tmp) > 17520 * amf_cfg$min.data.to.check) {
          ## check out-range data
          outlier.loc2.1 <-
            which((data1.tmp > FP_ls$Max[
              which(FP_ls$Name == check.limit.grab.basename[j1])] &
                data1.tmp < FP_ls$Max_buff[
                  which(FP_ls$Name == check.limit.grab.basename[j1])]) |
                (data1.tmp < FP_ls$Min[
                  which(FP_ls$Name == check.limit.grab.basename[j1])] &
                   data1.tmp > FP_ls$Min_buff[
                     which(FP_ls$Name == check.limit.grab.basename[j1])])
            )
          outlier.loc3.1 <-
            which(data1.tmp >= FP_ls$Max_buff[
              which(FP_ls$Name == check.limit.grab.basename[j1])] |
                data1.tmp <= FP_ls$Min_buff[
                  which(FP_ls$Name == check.limit.grab.basename[j1])])

          physical.stat <- data.frame(
            year = scan.year[j2],
            var = check.limit.grab[j1],
            soft_flag = length(outlier.loc2.1) / length(data1.tmp),
            hard_flag = length(outlier.loc3.1) / length(data1.tmp),
            variability = "ok",
            status = "ok"
          )

          ## check IQR
          data1.tmp.iqr <- IQR(data1.tmp, na.rm = T)
          FP_iqr.sub <-
            FP_ls[which(FP_ls$Name == check.limit.grab.basename[j1]),]

          if ((
            length(outlier.loc2.1) >
            amf_cfg$soft.flag.threshold * length(data1.tmp) &
            !check.limit.grab.basename[j1] %in% amf_cfg$loosen.var
          ) |
          length(outlier.loc3.1) >
          amf_cfg$hard.flag.threshold * length(data1.tmp) |
          (
            run.iqr & scan.year[j2] %in% scan.fullyear &
            !is.na(FP_iqr.sub$IQR.01) &
            !is.na(FP_iqr.sub$IQR.99) &
            (
              data1.tmp.iqr < FP_iqr.sub$IQR.01 |
              data1.tmp.iqr > FP_iqr.sub$IQR.99
            )
          ) |
          plot.always) {
            amf_chk_physical_range(
              case = paste0(site, "_", scan.year[j2]),
              path.out = path.out,
              var.name = check.limit.grab[j1],
              base.name = check.limit.grab.basename[j1],
              TIMESTAMP = TIMESTAMP[which(TIMESTAMP$year + 1900 == scan.year[j2])],
              data1.tmp = data1.tmp,
              outlier.loc2.1 = outlier.loc2.1,
              outlier.loc3.1 = outlier.loc3.1,
              limit.ls = FP_ls,
              iqr.min = ifelse(nrow(FP_iqr.sub) == 1, FP_iqr.sub$IQR.01, NULL),
              iqr.max = ifelse(nrow(FP_iqr.sub) == 1, FP_iqr.sub$IQR.99, NULL)
            )

            if (length(outlier.loc3.1) >
                amf_cfg$hard.flag.threshold * length(data1.tmp)) {
              print(paste(
                "[Fail] Excessive outliers:",
                check.limit.grab[j1],
                scan.year[j2]
              ))
              physical.stat$status <- "fail"
            } else if (length(outlier.loc2.1) >
                       amf_cfg$soft.flag.threshold * length(data1.tmp) &
                       !check.limit.grab.basename[j1] %in% amf_cfg$loosen.var) {
              print(paste(
                "[Warning] Slight outliers:",
                check.limit.grab[j1],
                scan.year[j2]
              ))
              physical.stat$status <- "warning"
            }

            if (run.iqr & scan.year[j2] %in% scan.fullyear &
                !is.na(FP_iqr.sub$IQR.01) &
                data1.tmp.iqr < FP_iqr.sub$IQR.01) {
              print(paste(
                "[Warning] Lower variability:",
                check.limit.grab[j1],
                scan.year[j2]
              ))
              physical.stat$variability <- "low"
            }

            if (run.iqr & scan.year[j2] %in% scan.fullyear &
                !is.na(FP_iqr.sub$IQR.99) &
                data1.tmp.iqr > FP_iqr.sub$IQR.99) {
              print(paste(
                "[Warning] Higher variability:",
                check.limit.grab[j1],
                scan.year[j2]
              ))
              physical.stat$variability <- "high"
            }
          }
          physical.stat.all <- rbind.data.frame(physical.stat.all,
                                                physical.stat)
        }
      }
    }

    if (output.stat)
      write.csv(
        physical.stat.all,
        file.path(
          path.out,paste0(
          target.site[i1],
          "_allyear_stat_physical_range.csv"
        )),
        row.names = F
      )
  }

  print("Physical limit check -- done")

  ##############################################################################
  ## Check ratio/percentage
  if (run.ratio &
      length(scan.year) > 0) {
    get.percentage.var <-
      basename_work$variable_name[
        which(basename_work$basename %in% amf_cfg$FP_per_ls)]

    if (length(get.percentage.var) > 0) {
      for (j3 in 1:length(get.percentage.var)) {
        for (j4 in 1:length(scan.year)) {
          data2.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[j4]),
                  get.percentage.var[j3]]

          count.ratio.percentage <-
            sum(
              !is.na(data2.tmp) &
                data2.tmp > 0 - amf_cfg$buffer.precentage &
                data2.tmp < 1 + amf_cfg$buffer.precentage,
              na.rm = T
            )
          if (count.ratio.percentage > 0.9 * length(na.omit(data2.tmp)))
            print(paste(
              "[Fail] Percentage variable in ratio:",
              get.percentage.var[j3],
              scan.year[j4]
            ))

        }
      }
    }
  }

  print("Check ratio/percentage -- done")

  ##############################################################################
  ## Check units
  if (run.unit &
      length(scan.year) > 0) {
    get.unit.var <-
      basename_work$variable_name[
        which(basename_work$basename %in% amf_cfg$unit.var.ls)]
    get.unit.var.basename <-
      basename_work$basename[
        which(basename_work$basename %in% amf_cfg$unit.var.ls)]

    if (length(get.unit.var) > 0) {
      for (k3 in 1:length(get.unit.var)) {
        for (k4 in 1:length(scan.year)) {
          data12.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[k4]),
                  get.unit.var[k3]]

          count.unit.percentage <-
            sum(
              !is.na(data12.tmp) &
                data12.tmp * amf_cfg$unit.var.scale.ls[
                  which(amf_cfg$unit.var.ls == get.unit.var.basename[k3])] >=
                FP_ls$q001.01[FP_ls$Name == get.unit.var.basename[k3]] &
                data12.tmp * amf_cfg$unit.var.scale.ls[
                  which(amf_cfg$unit.var.ls == get.unit.var.basename[k3])] <=
                FP_ls$q999.99[FP_ls$Name == get.unit.var.basename[k3]],
              na.rm = T
            )

          if (count.unit.percentage > 0.9 * length(na.omit(data12.tmp)))
            print(paste("[Warning] Possibly wrong unit:",
                        get.unit.var[k3],
                        scan.year[k4]))

        }
      }
    }
  }

  print("Check units -- done")

  ##############################################################################
  ## run VPD check
  if (run.vpd &
      length(scan.year) > 0) {
    get.vpd.var <-
      basename_work$variable_name[
        which(basename_work$basename %in% "VPD")]
    get.ta.var <-
      basename_work$variable_name[
        which(basename_work$variable_name %in% c("TA", "TA_1", "TA_1_1_1"))][1]
    get.rh.var <-
      basename_work$variable_name[
        which(basename_work$variable_name %in% c("RH", "RH_1", "RH_1_1_1"))][1]

    if (length(get.vpd.var) > 0 &
        length(get.ta.var) > 0 &
        length(get.rh.var) > 0) {
      for (k5 in 1:length(get.vpd.var)) {
        for (k6 in 1:length(scan.year)) {
          data13.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[k6]), get.vpd.var[k5]]
          data14.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[k6]), get.ta.var]
          data15.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[k6]), get.rh.var]

          if (sum.notna(data13.tmp) >
              amf_cfg$min.data.to.check * 17520 &
              sum.notna(data14.tmp) >
              amf_cfg$min.data.to.check * 17520 &
              sum.notna(data15.tmp) >
              amf_cfg$min.data.to.check * 17520 &
              sum.three.notna(data13.tmp, data14.tmp, data15.tmp) >
              amf_cfg$min.data.to.check * 17520 &
              var(data13.tmp[!is.na(data14.tmp) &
                             !is.na(data15.tmp)], na.rm = T) > 0) {
            check.vpd.out <- amf_chk_vpd(
              vpd.data = data13.tmp,
              ta.data = data14.tmp,
              rh.data = data15.tmp,
              out.path = out.path,
              plot.always = plot.always,
              case = paste0(site, "_", scan.year[k6]),
              var.name = get.vpd.var[k5],
              TIMESTAMP = TIMESTAMP[which(TIMESTAMP$year + 1900 == scan.year[k6])]
            )

            if (abs(check.vpd.out$slope - 1) > 0.2)
              print(paste("[Fail] Very likely wrong unit:",
                          get.vpd.var[k5],
                          scan.year[k6]))
          }
        }
      }
    } else if (length(get.vpd.var) > 0 &
               length(get.ta.var) > 0 &
               length(get.rh.var) == 0) {
      print(paste("[Info] Missing observed RH for VPD check:",
                  get.vpd.var[k5],
                  scan.year[k6]))

      check.vpd.out <- amf_chk_vpd(
        vpd.data = data13.tmp,
        ta.data = data14.tmp,
        rh.data = rep(seq(20, 100, by = 10),
                      ceiling(length(data13.tmp) / 9))[c(1:length(data13.tmp))],
        out.path = out.path,
        plot.always = TRUE,
        case = paste0(site, "_", scan.year[k6]),
        var.name = paste0(get.vpd.var[k5], "_sim"),
        TIMESTAMP = TIMESTAMP[which(TIMESTAMP$year + 1900 == scan.year[k6])]
      )
    }
  }

  print("run VPD check -- done")

  ##############################################################################
  ## Check sign convention
  #browser()
  #--> The following fails if it's a new site (i.e. not registered with Ameriflux)
  #--> Quick solution would be to set run.sign<-FALSE to skip
  if (run.sign &
      length(which(sgi.ameriflux$SITE_ID == target.site[i1])) > 0 &
      length(scan.year) > 0) {
    get.sign.var <-
      basename_work$variable_name[
        which(basename_work$basename %in% sign.var.ls[[1]])]
    get.sign.var.basename <-
      basename_work$basename[
        which(basename_work$basename %in% sign.var.ls[[1]])]

    if (length(get.sign.var) > 0) {
      for (k1 in 1:length(get.sign.var)) {
        for (k2 in 1:length(scan.year)) {
          data11.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[k2]),
                  get.sign.var[k1]]
          TIMESTAMP.sub <-
            TIMESTAMP[which(TIMESTAMP$year + 1900 == scan.year[k2])]

          ## locate summer months
          if (as.numeric(sgi.ameriflux$LOCATION_LAT[
            which(sgi.ameriflux$SITE_ID == target.site[i1])]) > 0) {
            summer.mon <- c(6:8)
          } else{
            summer.mon <- c(12, 1, 2)
          }

          if (get.sign.var.basename[k1] %in%
              colnames(sign.var.prototype[[
                ifelse(target.res == "HH", 1, 2)]])) {
            get.sign.var.prototype <-
              sign.var.prototype[[
                ifelse(target.res == "HH", 1, 2)]][, get.sign.var.basename[k1]]
          } else{
            get.sign.var.prototype <- NULL
          }
          var.prototype = get.sign.var.prototype

          if (sum.notna(data11.tmp) > 17520 * amf_cfg$min.data.to.check &
              sum.notna(data11.tmp[
                which((TIMESTAMP.sub$mon + 1) %in% summer.mon)]) >
              0.5 * d.hr * 90 &
              length(TIMESTAMP.sub[
                which((TIMESTAMP.sub$mon + 1) %in% summer.mon)]) >
              0.5 * d.hr * 90) {
            check_sign.out <- amf_chk_sign(
              data.in = data11.tmp,
              var.name = get.sign.var[k1],
              TIMESTAMP.sub = TIMESTAMP.sub,
              var.sign = sign.var.ls$sign[
                which(sign.var.ls$var == get.sign.var.basename[k1])],
              var.prototype = var.prototype,
              case = paste0(site, "_", scan.year[k2]),
              path.out = path.out,
              summer.mon = summer.mon,
              plot.always = plot.always
            )

            if (!is.na(sign.var.ls$sign[
              which(sign.var.ls$var == get.sign.var.basename[k1])]) &
              (!is.na(check_sign.out[[1]]) &
               check_sign.out[[1]]))
              print(paste(
                "[Warning] Possible sign convention error:",
                get.sign.var[k1],
                scan.year[k2]
              ))

            if (!is.null(get.sign.var.prototype) &
                (!is.na(check_sign.out[[3]]) &
                 check_sign.out[[3]] < 0))
              print(paste(
                "[Warning] Possible sign convention error:",
                get.sign.var[k1],
                scan.year[k2]
              ))
          }
        }
      }
    }
  }

  print("Check sign convention -- done")

  ##############################################################################
  ## Check wind sigma variables
  if (run.sigmaw &
      length(scan.year) > 0) {
    #  focus on sigma w as it's less variable across sites
    get.sigma.var <-
      basename_work$variable_name[
        which(basename_work$basename == "W_SIGMA")]
    if (length(get.sigma.var) > 1) {
      get.sigma.var <-
        get.sigma.var[
          which(get.sigma.var %in% c("W_SIGMA", "W_SIGMA_1_1_1", "W_SIGMA_1"))][1]
    } else if (length(get.sigma.var) == 0) {
      get.sigma.var <- NA
    }
    get.ustar <-
      basename_work$variable_name[which(basename_work$basename == "USTAR")]
    if (length(get.ustar) > 1) {
      get.ustar <-
        get.ustar[which(get.ustar %in% c("USTAR", "USTAR_1_1_1", "USTAR_1"))][1]
    } else if (length(get.ustar) == 0) {
      get.ustar <- NA
    }
    get.zL <-
      basename_work$variable_name[which(basename_work$basename == "ZL")][1]

    if (!is.na(get.sigma.var) &
        length(get.sigma.var) == 1 &
        !is.na(get.ustar) &
        length(get.ustar) == 1) {
      for (j5 in 1:length(scan.year)) {
        data3.tmp <-
          data1[which(TIMESTAMP$year + 1900 == scan.year[j5]), get.sigma.var]
        data4.tmp <-
          data1[which(TIMESTAMP$year + 1900 == scan.year[j5]), get.ustar]

        if (sum.notna(data3.tmp) >
            amf_cfg$min.data.to.check * 17520 &
            sum.notna(data4.tmp) >
            amf_cfg$min.data.to.check * 17520 &
            sum.both.notna(data3.tmp, data4.tmp) >
            amf_cfg$min.data.to.check * 17520) {
          if (length(get.zL) == 1) {
            data5.tmp <-
              data1[which(TIMESTAMP$year + 1900 == scan.year[j5]), get.zL]
            if (sum.notna(data5.tmp) < 30)
              data5.tmp <- NULL
          } else{
            data5.tmp <- NULL
          }

          check_sigma_w.out <- amf_chk_sigma(
            ustar = data4.tmp,
            ustar.name = get.ustar,
            sigmaw = data3.tmp,
            sigmaw.name = get.sigma.var,
            zL = data5.tmp,
            case = site,
            year = scan.year[j5],
            path.out = path.out,
            slope.dev.threshold = amf_cfg$wslope.dev.threshold,
            plot_always = plot.always
          )

          if (abs(check_sigma_w.out$slope[1] - 1.25) >
              amf_cfg$wslope.dev.threshold * 1.25 |
              (
                !is.na(check_sigma_w.out$slope[2]) &
                abs(check_sigma_w.out$slope[2] - 1.25) >
                amf_cfg$wslope.dev.threshold * 1.25
              )) {
            print(paste("[Warning] SIGMA_W unexpected:",
                        get.sigma.var,
                        scan.year[j5]))

            check_sigma_w.out2 <- amf_chk_sigma(
              ustar = data4.tmp,
              ustar.name = get.ustar,
              sigmaw = sqrt(data3.tmp),
              sigmaw.name = paste0(get.sigma.var, "^0.5"),
              zL = data5.tmp,
              case = site,
              year = scan.year[j5],
              path.out = path.out,
              plot_always = plot.always,
              extention = "_sqrtroot"
            )
          }
        }
      }
    }
  }

  print("Check wind sigma variables -- done")

  ##############################################################################
  ## Ustar filtering check
  if (run.ustar &
      length(scan.year) > 0) {
    get.fc <-
      basename_work$variable_name[which(basename_work$basename == "FC" &
                                          !basename_work$is_gapfill)]
    if (length(get.fc) > 1) {
      get.fc <- get.fc[which(get.fc %in% c("FC", "FC_1_1_1", "FC_1"))]
    } else if (length(get.fc) == 0) {
      get.fc <- NA
    }
    get.ustar <-
      basename_work$variable_name[which(basename_work$basename == "USTAR")]
    if (length(get.ustar) > 1) {
      get.ustar <-
        get.ustar[which(get.ustar %in% c("USTAR", "USTAR_1_1_1", "USTAR_1"))][1]
    } else if (length(get.ustar) == 0) {
      get.ustar <- NA
    }

    if (!is.na(get.fc) &
        !is.na(get.ustar) &
        length(get.ustar) == 1 &
        !is.null(SW_IN_POT)) {
      ustar.stat.all <- NULL

      for (j7 in 1:length(scan.year)) {
        for (j8 in 1:length(get.fc)) {
          data5.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[j7]), get.fc[j8]]
          data6.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[j7]), get.ustar]
          SW_IN_POT.sub1 <- SW_IN_POT[[j7]]
          time.i <-
            data1$TIMESTAMP_START[
              which(TIMESTAMP$year + 1900 == scan.year[j7])][1]
          time.f <-
            data1$TIMESTAMP_START[
              which(TIMESTAMP$year + 1900 == scan.year[j7])][
                length(data1$TIMESTAMP_START[
                  which(TIMESTAMP$year + 1900 == scan.year[j7])])]

          SW_IN_POT.sub1 <-
            SW_IN_POT.sub1[c(
              which(SW_IN_POT.sub1$TIMESTAMP_START == time.i):
                which(SW_IN_POT.sub1$TIMESTAMP_START == time.f)
            ),]

          if (sum.notna(data5.tmp) >
              17520 * amf_cfg$min.data.to.check &
              sum.notna(data6.tmp) >
              17520 * amf_cfg$min.data.to.check &
              sum.both.notna(data5.tmp, data6.tmp) >
              17520 * amf_cfg$min.data.to.check) {
            ustar.stat <- amf_chk_ustar_filter(
              ustar_data = data6.tmp,
              ustar_name = get.ustar,
              fc_data = data5.tmp,
              fc_name = get.fc[j8],
              radiation_data = SW_IN_POT.sub1$SW_IN_POT,
              radiation_threshold = 0,
              year = scan.year[j7],
              ustar.low.threshold1 = amf_cfg$ustar.low.threshold1,
              ustar.low.threshold2 = amf_cfg$ustar.low.threshold2,
              ustar.diff.threshold1 = amf_cfg$ustar.diff.threshold1,
              ustar.diff.threshold2 = amf_cfg$ustar.diff.threshold2
            )

            ustar.stat.all <- rbind.data.frame(ustar.stat.all,
                                               ustar.stat)
          }
        }
      }

      if (output.stat)
        write.csv(
          ustar.stat.all,
          paste0(path.out, target.site[i1], "_allyear_stat_ustar.csv"),
          row.names = F
        )
    } else{
      print(paste(
        "[Info] Missing required variables, skip ustar-filtering check"
      ))

    }
  }

  print("Ustar filtering check -- done")

  ##############################################################################
  ## Multivariate check
  #  Use designated years or all years for detecting slope deviations
  if (check.multivarite.all.year) {
    scan.year.multivariate <- scan.fullyear
  } else{
    scan.year.multivariate <- scan.year
  }

  if (run.multivariate &
      length(scan.year.multivariate) > 0) {
    multi.var.stat.all <- data.frame(NULL)

    ## loop through target variable pairs
    for (vv3 in 1:length(amf_cfg$multi.var.pair[[1]])) {
      get.var1 <-
        basename_work$variable_name[which(
          basename_work$basename == amf_cfg$multi.var.pair[[1]][vv3] &
            !basename_work$is_gapfill &
            (
              is.na(basename_work$qualifier_pos) |
                (
                  !is.na(basename_work$qualifier_pos) &
                    basename_work$qualifier_pos == "_1_1_1"
                ) |
                (
                  !is.na(basename_work$layer_index) &
                    basename_work$layer_index == "_1"
                )
            )
        )]
      get.var2 <-
        basename_work$variable_name[which(
          basename_work$basename == amf_cfg$multi.var.pair[[2]][vv3] &
            !basename_work$is_gapfill &
            (
              is.na(basename_work$qualifier_pos) |
                (
                  !is.na(basename_work$qualifier_pos) &
                    basename_work$qualifier_pos == "_1_1_1"
                ) |
                (
                  !is.na(basename_work$layer_index) &
                    basename_work$layer_index == "_1"
                )
            )
        )]
      if (length(get.var1) == 0)
        get.var1 <- NA

      if (length(get.var2) == 0)
        get.var2 <- NA

      if (sum(!is.na(get.var1)) > 0 &
          sum(!is.na(get.var2)) > 0) {
        multi.var.stat <- data.frame(NULL)

        for (m1 in 1:length(get.var1)) {
          for (m2 in 1:length(get.var2)) {
            for (m3 in 1:length(scan.year.multivariate)) {
              data8.tmp <-
                data1[which(TIMESTAMP$year + 1900 == scan.year.multivariate[m3]),
                      get.var1[m1]]
              data9.tmp <-
                data1[which(TIMESTAMP$year + 1900 == scan.year.multivariate[m3]),
                      get.var2[m2]]

              if (sum.notna(data8.tmp) >
                  17520 * amf_cfg$min.data.to.check &
                  sum.notna(data9.tmp) >
                  17520 * amf_cfg$min.data.to.check &
                  sum.both.notna(data8.tmp, data9.tmp) >
                  17520 * amf_cfg$min.data.to.check) {
                mcheck.out <- amf_chk_multivar(
                  site = target.site[i1],
                  year = scan.year.multivariate[m3],
                  full.time = TIMESTAMP[
                    which(TIMESTAMP$year + 1900 == scan.year.multivariate[m3])],
                  target.name1 = get.var1[m1],
                  target.unit1 = amf_cfg$multi.var.pair.unit[[1]][vv3],
                  target.name2 = get.var2[m2],
                  target.unit2 = amf_cfg$multi.var.pair.unit[[2]][vv3],
                  target.data1 = data8.tmp,
                  target.data2 = data9.tmp,
                  rsquare.threshold = amf_cfg$rsquare.threshold[vv3],
                  outlier.threshold = amf_cfg$outlier.threshold,
                  outlier.dev.threshold = amf_cfg$outlier.dev.threshold,
                  path.out = path.out,
                  plot.all = plot.always
                )

                multi.var.stat <- rbind.data.frame(multi.var.stat,
                                                   mcheck.out)

                ## fail message per year
                if (mcheck.out$rsqure < amf_cfg$rsquare.threshold[vv3] |
                    mcheck.out$outlier > amf_cfg$outlier.threshold |
                    mcheck.out$rsqure == 1) {
                  print(
                    paste(
                      "[Warning] Potential multivariate issue:",
                      get.var1[m1],
                      get.var2[m2],
                      scan.year.multivariate[m3]
                    )
                  )
                }
              } else {
                # skip a year if insufficient data
                #multi.var.stat <- NULL

              }
            }
          }
        }

        #### work on multiyear
        if (length(scan.year) > 1 &
            nrow(multi.var.stat) >= amf_cfg$min.year.multivarite) {
          multi.var.stat.out <-
            amf_chk_multivar_multiyear(
              site = target.site[i1],
              multi.var.stat = multi.var.stat,
              mslope.dev.threshold = amf_cfg$mslope.dev.threshold,
              rsquare.threshold = amf_cfg$rsquare.threshold[vv3],
              path.out = path.out,
              plot.all = plot.always
            )

          ## work on fail messages
          if (any(
            !is.na(multi.var.stat.out$slope.dev) &
            abs(multi.var.stat.out$slope.dev) > amf_cfg$mslope.dev.threshold
          )) {
            print(
              paste(
                "[Warning] Potential multivariate issue:",
                get.var1[m1],
                get.var2[m2],
                "slightly deviated slopes in",
                paste(multi.var.stat.out$year[
                  which(abs(multi.var.stat.out$slope.dev) >
                          amf_cfg$mslope.dev.threshold)],
                  collapse = "/")
              )
            )

          } else if (any(
            !is.na(multi.var.stat.out$slope.dev) &
            abs(multi.var.stat.out$slope.dev) >
            amf_cfg$mslope.dev.threshold2
          )) {
            print(
              paste(
                "[Fail] Multivariate issue:",
                get.var1[m1],
                get.var2[m2],
                "evidently deviated slopes in",
                paste(multi.var.stat.out$year[
                  which(abs(multi.var.stat.out$slope.dev) >
                          amf_cfg$mslope.dev.threshold2)],
                  collapse = "/")
              )
            )
          }
          ## status
          multi.var.stat.out$status <- "ok"
          multi.var.stat.out$status[(!is.na(multi.var.stat.out$rsqure) &
                                       multi.var.stat.out$rsqure == 1) |
                                      (
                                        !is.na(multi.var.stat.out$slope.dev) &
                                          abs(multi.var.stat.out$slope.dev) >
                                          amf_cfg$mslope.dev.threshold2
                                      )] <- "fail"
          multi.var.stat.out$status[(
            !is.na(multi.var.stat.out$rsqure) &
              multi.var.stat.out$rsqure < amf_cfg$rsquare.threshold[vv3]
          ) |
            (
              !is.na(multi.var.stat.out$outlier) &
                multi.var.stat.out$outlier > amf_cfg$outlier.threshold
            ) |
            (
              !is.na(multi.var.stat.out$slope.dev) &
                abs(multi.var.stat.out$slope.dev) >
                amf_cfg$mslope.dev.threshold &
                abs(multi.var.stat.out$slope.dev) <
                amf_cfg$mslope.dev.threshold2
            )] <- "warning"

          multi.var.stat.all <- rbind.data.frame(multi.var.stat.all,
                                                 multi.var.stat.out)

        }
      } else{
        print(
          paste(
            "[Info] Skip multivariate check:",
            amf_cfg$multi.var.pair[[1]][vv3],
            amf_cfg$multi.var.pair[[2]][vv3]
          )
        )

        multi.var.stat.all <- data.frame(matrix(
          ncol = 15,
          nrow = 0,
          dimnames = list(
            NULL,
            c(
              "year",
              "var1",
              "var2",
              "var1_missing",
              "var2_missing",
              "var_pair_n",
              "rsqure",
              "slope",
              "intercept",
              "dev_std",
              "outlier",
              "slope.dev",
              "flag_rsquare",
              "flag_slope",
              "status"
            )
          )
        ))

      }
    }

    if (output.stat)
      write.csv(
        multi.var.stat.all,
        paste0(path.out, target.site[i1], "_allyear_stat_multivariate.csv"),
        row.names = F
      )
  }

  print("Multivariate check -- done")

  #######################################################################################################
  #### Timestamp alignment check
  if (run.timestamp &
      length(scan.year) > 0) {
    get.sw_in <-
      basename_work$variable_name[which(basename_work$basename == "SW_IN" &
                                          !basename_work$is_gapfill)]
    if (length(get.sw_in) > 1) {
      get.sw_in <-
        get.sw_in[which(get.sw_in %in%
                          c("SW_IN", "SW_IN_1_1_1", "SW_IN_1"))]
    } else if (length(get.sw_in) == 0) {
      get.sw_in <- NA
    }
    get.ppfd_in <-
      basename_work$variable_name[which(basename_work$basename == "PPFD_IN" &
                                          !basename_work$is_gapfill)]
    if (length(get.ppfd_in) > 1) {
      get.ppfd_in <-
        get.ppfd_in[which(get.ppfd_in %in%
                            c("PPFD_IN", "PPFD_IN_1_1_1", "PPFD_IN_1"))]
    } else if (length(get.ppfd_in) == 0) {
      get.ppfd_in <- NA
    }

    if (!is.null(SW_IN_POT) &
        (sum(!is.na(get.sw_in)) > 0 |
         sum(!is.na(get.ppfd_in)) > 0)) {
      timestamp.stat.all <- NULL

      for (j9 in 1:length(scan.year)) {
        ## deal with all empty columns within a year
        target.var.radiation <-
          as.vector(na.omit(c(get.ppfd_in, get.sw_in)))
        target.var.radiation <-
          target.var.radiation[
            which(apply(as.data.frame(data1[
              which(TIMESTAMP$year + 1900 == scan.year[j9]),
              target.var.radiation]), 2, sum.notna) > 0)]

        if (length(target.var.radiation) > 0) {
          data7.tmp <-
            data1[which(TIMESTAMP$year + 1900 == scan.year[j9]),
                  c("TIMESTAMP_START",
                    "TIMESTAMP_END",
                    target.var.radiation)]

          SW_IN_POT.sub2 <- SW_IN_POT[[j9]]
          time.i2 <-
            data1$TIMESTAMP_START[
              which(TIMESTAMP$year + 1900 == scan.year[j9])][1]
          time.f2 <-
            data1$TIMESTAMP_START[
              which(TIMESTAMP$year + 1900 == scan.year[j9])][
                length(data1$TIMESTAMP_START[
                  which(TIMESTAMP$year + 1900 == scan.year[j9])])]

          SW_IN_POT.sub2 <-
            SW_IN_POT.sub2[c(
              which(SW_IN_POT.sub2$TIMESTAMP_START == time.i2):
                which(SW_IN_POT.sub2$TIMESTAMP_START == time.f2)
            ),]

          timestamp.check.out <- amf_chk_timestamp_alignment(
            data = cbind.data.frame(data7.tmp,
                                    SW_IN_POT = SW_IN_POT.sub2$SW_IN_POT),
            name = paste0(site, "_", scan.year[j9]),
            l.window = 15,
            PAR.coefff = 0.5,
            target.var = target.var.radiation,
            res = target.res,
            path.out = path.out,
            night.buffer = amf_cfg$night.buffer,
            # 10 W m-2
            day.threshold = ifelse(target.res == "HH",
                                   amf_cfg$day.threshold[1],
                                   amf_cfg$day.threshold[2]),
            night.threshold = ifelse(
              target.res == "HH",
              amf_cfg$night.threshold[1],
              amf_cfg$night.threshold[2]
            ),
            plot.always = plot.always
          )

          timestamp.stat <-
            data.frame(
              year = rep(scan.year[j9], length(target.var.radiation)),
              var = target.var.radiation,
              time_lag = NA,
              corr = NA,
              day_flagged = NA,
              night_flagged = NA,
              status = NA
            )

          for (ttt in 1:length(timestamp.check.out$all.error.count.d)) {
            timestamp.stat$time_lag[ttt] <-
              timestamp.check.out$all.error.ccf[[ttt]][, 2]
            timestamp.stat$corr[ttt] <-
              timestamp.check.out$all.error.ccf[[ttt]][, 3]
            timestamp.stat$day_flagged[ttt] <-
              timestamp.check.out$all.error.count.d[[ttt]]
            timestamp.stat$night_flagged[ttt] <-
              timestamp.check.out$all.error.count.n[[ttt]]

            if (!is.na(timestamp.stat$time_lag[ttt]) &
                timestamp.stat$time_lag[ttt] != 0 &
                !is.na(timestamp.stat$corr[ttt]) &
                timestamp.stat$corr[ttt] > 0.4 &
                ((
                  timestamp.stat$day_flagged[ttt] > 0 &
                  timestamp.stat$day_flagged[ttt] <= ifelse(
                    target.res == "HH",
                    amf_cfg$day.threshold[1],
                    amf_cfg$day.threshold[2]
                  )
                ) |
                (
                  timestamp.stat$night_flagged[ttt] > 0 &
                  timestamp.stat$night_flagged[ttt] <= ifelse(
                    target.res == "HH",
                    amf_cfg$night.threshold[1],
                    amf_cfg$night.threshold[2]
                  )
                )
                )) {
              timestamp.stat$status[ttt] <- "fail"

            } else if (timestamp.stat$day_flagged[ttt] >
                       ifelse(target.res == "HH",
                              amf_cfg$day.threshold[1],
                              amf_cfg$day.threshold[2]) |
                       timestamp.stat$night_flagged[ttt] >
                       ifelse(target.res == "HH",
                              amf_cfg$night.threshold[1],
                              amf_cfg$night.threshold[2])) {
              timestamp.stat$status[ttt] <- "fail"

            } else if (!is.na(timestamp.stat$time_lag[ttt]) &
                       timestamp.stat$time_lag[ttt] != 0 &
                       !is.na(timestamp.stat$corr[ttt]) &
                       timestamp.stat$corr[ttt] > 0.4) {
              timestamp.stat$status[ttt] <- "warning"
            } else if ((
              timestamp.stat$day_flagged[ttt] > 0 &
              timestamp.stat$day_flagged[ttt] <= ifelse(
                target.res == "HH",
                amf_cfg$day.threshold[1],
                amf_cfg$day.threshold[2]
              )
            ) |
            (
              timestamp.stat$night_flagged[ttt] > 0 &
              timestamp.stat$night_flagged[ttt] <= ifelse(
                target.res == "HH",
                amf_cfg$night.threshold[1],
                amf_cfg$night.threshold[2]
              )
            )) {
              timestamp.stat$status[ttt] <- "warning"

            } else {
              timestamp.stat$status[ttt] <- "ok"
            }
          }
          timestamp.stat.all <- rbind.data.frame(timestamp.stat.all,
                                                 timestamp.stat)

          if (timestamp.check.out$any.error) {
            if (sum(timestamp.check.out$all.error.count.d >
                    amf_cfg$day.threshold,
                    na.rm = T) > 0)
              print(paste(
                "[Warning] Timestamp issue: excessive daytime radiation",
                paste(as.vector(na.omit(
                  c(get.ppfd_in, get.sw_in)
                ))[which(
                  timestamp.check.out$all.error.count.d > ifelse(
                    target.res == "HH",
                    amf_cfg$day.threshold[1],
                    amf_cfg$day.threshold[2]
                  )
                )],
                scan.year[j9], collapse = ", ")
              ))

            if (sum(timestamp.check.out$all.error.count.n >
                    amf_cfg$night.threshold,
                    na.rm = T) > 0)
              print(paste(
                "[Warning] Timestamp issue: excessive nighttime radiation",
                paste(as.vector(na.omit(
                  c(get.ppfd_in, get.sw_in)
                ))[which(
                  timestamp.check.out$all.error.count.n > ifelse(
                    target.res == "HH",
                    amf_cfg$night.threshold[1],
                    amf_cfg$night.threshold[2]
                  )
                )],
                scan.year[j9], collapse = ", ")
              ))

            if (sum(sapply(timestamp.check.out$all.error.ccf,
                           sum.notna) > 0) > 0) {
              get.error.var <-
                which(sapply(timestamp.check.out$all.error.ccf,
                             sum.notna) > 0)

              for (vv2 in 1:length(get.error.var)) {
                if (timestamp.check.out$all.error.ccf[[
                  get.error.var[vv2]]]$max.ccf.lag != 0) {
                  print(paste(
                    "[Fail] Timestamp issue: shifted",
                    paste(
                      as.vector(na.omit(
                        c(get.ppfd_in, get.sw_in)
                      ))[get.error.var[vv2]],
                      scan.year[j9],
                      collapse = ", "
                    )
                  ))
                }
              }
            }

          }
        }

      }

      if (output.stat)
        write.csv(
          timestamp.stat.all,
          paste0(path.out, target.site[i1], "_allyear_stat_timestamp.csv"),
          row.names = F
        )
    } else{
      print(
        paste(
          "[Info] Missing required data/metadata, skip timestamp alignment check"
        )
      )
    }
  }

  print("Timestamp alignment check")

  ##############################################################################
  ## Diurnal-seasonal checks
  if (run.diurnalseasonal &
      length(scan.year) > 0) {
    ## Create time id for diel-seasonal aggregation, apply func
    DOY2 <- floor(TIMESTAMP$yday / amf_cfg$l.wd) + 1
    DOY2[which(DOY2 == max(DOY2, na.rm = T))] <- amf_cfg$n.wd
    # wrap all hanging days into last window
    HR2 <- TIMESTAMP$hour + TIMESTAMP$min / 60

    site.threshold.ls <-
      dir(paste0(seasonal.dir, amf_cfg$threshold.ver, "\\"),
          pattern = ".csv")[
            grep(site, dir(paste0(seasonal.dir, amf_cfg$threshold.ver, "\\"),
                           pattern = ".csv"))]

    ## find historical threshold
    if (length(site.threshold.ls) == 5) {
      med.bd <- read.csv(
        paste0(seasonal.dir, amf_cfg$threshold.ver, "\\",
               site.threshold.ls[grep("MEDIAN", site.threshold.ls)]),
        na = "-9999",
        header = T
      )
      upp.bd1 <- read.csv(
        paste0(seasonal.dir, amf_cfg$threshold.ver, "\\",
               site.threshold.ls[grep("UPPER1", site.threshold.ls)]),
        na = "-9999",
        header = T
      )
      upp.bd2 <- read.csv(
        paste0(seasonal.dir, amf_cfg$threshold.ver, "\\",
               site.threshold.ls[grep("UPPER2", site.threshold.ls)]),
        na = "-9999",
        header = T
      )
      low.bd1 <- read.csv(
        paste0(seasonal.dir, amf_cfg$threshold.ver, "\\",
               site.threshold.ls[grep("LOWER1", site.threshold.ls)]),
        na = "-9999",
        header = T
      )
      low.bd2 <- read.csv(
        paste0(seasonal.dir, amf_cfg$threshold.ver, "\\",
               site.threshold.ls[grep("LOWER2", site.threshold.ls)]),
        na = "-9999",
        header = T
      )

      chk.ls2 <- colnames(med.bd)[-c(1:2)]

      diurseasonal.stat.all <- NULL

      #### Loop through target variables
      for (i2 in 1:length(chk.ls2)) {
        if (chk.ls2[i2] %in% colnames(data1)) {
          for (j in 1:length(scan.year)) {
            if (sum(!is.na(data1[(TIMESTAMP$year + 1900) == scan.year[j],
                                 chk.ls2[i2]])) >
                amf_cfg$min.data.to.check *
                length(data1[(TIMESTAMP$year + 1900) == scan.year[j],
                             chk.ls2[i2]])) {
              #### check historical range
              diurseasonal.stat <- amf_chk_diurnal_seasonal(
                data.sel = data.frame(
                  TIMESTAMP = TIMESTAMP[(TIMESTAMP$year + 1900) == scan.year[j]],
                  DOY2 = DOY2[(TIMESTAMP$year + 1900) == scan.year[j]],
                  HR2 = HR2[(TIMESTAMP$year + 1900) == scan.year[j]],
                  var = data1[(TIMESTAMP$year + 1900) ==
                                scan.year[j], chk.ls2[i2]]
                ),
                thres.in = data.frame(
                  DOY2 = med.bd$DOY2,
                  HR2 = med.bd$HR2,
                  upp.bd2 = upp.bd2[, chk.ls2[i2]],
                  upp.bd1 = upp.bd1[, chk.ls2[i2]],
                  med.bd = med.bd[, chk.ls2[i2]],
                  low.bd1 = low.bd1[, chk.ls2[i2]],
                  low.bd2 = low.bd2[, chk.ls2[i2]]
                ),
                var.name = chk.ls2[i2],
                site = site,
                year = scan.year[j],
                d.hr = d.hr,
                n.wd = max(DOY2[(TIMESTAMP$year + 1900) == scan.year[j]]),
                path.out = path.out,
                Q1Q3.threshold = amf_cfg$Q1Q3.threshold,
                Q95.threshold = amf_cfg$Q95.threshold,
                Q1Q3.threshold2 = amf_cfg$Q1Q3.threshold2,
                Q95.threshold2 = amf_cfg$Q95.threshold2,
                plot_always = plot.always
              )
              diurseasonal.stat$status <- "ok"

              if ((diurseasonal.stat$wihtin_95per_range < amf_cfg$Q95.threshold) |
                  (diurseasonal.stat$wihtin_Q1Q3_range < amf_cfg$Q1Q3.threshold) |
                  (
                    !is.na(diurseasonal.stat$max_ccor) &
                    diurseasonal.stat$max_ccor < (-0.4)
                  )) {
                print(
                  paste(
                    "[Fail] Evident shift diurnal-seasonal range:",
                    chk.ls2[i2],
                    scan.year[j]
                  )
                )
                diurseasonal.stat$status <- "fail"

              } else if ((
                diurseasonal.stat$wihtin_95per_range < amf_cfg$Q95.threshold2 &
                diurseasonal.stat$wihtin_95per_range > amf_cfg$Q95.threshold
              ) |
              (
                diurseasonal.stat$wihtin_Q1Q3_range < amf_cfg$Q1Q3.threshold2 &
                diurseasonal.stat$wihtin_Q1Q3_range > amf_cfg$Q1Q3.threshold
              ) |
              (
                !is.na(diurseasonal.stat$max_ccor) &
                abs(diurseasonal.stat$max_ccor) > 0.4 &
                !is.na(diurseasonal.stat$lag) &
                diurseasonal.stat$lag != 0
              )) {
                print(paste(
                  "[Warning] Slight shift diurnal-seasonal range:",
                  chk.ls2[i2],
                  scan.year[j]
                ))
                diurseasonal.stat$status <- "warning"
              }

              if ((diurseasonal.stat$all_constant[1]))
                print(paste("[Fail] All constant:", chk.ls2[i2], scan.year[j]))

              diurseasonal.stat.all <-
                rbind.data.frame(diurseasonal.stat.all,
                                 diurseasonal.stat)
            }
          }
        }
      }

      if (output.stat)
        write.csv(
          diurseasonal.stat.all,
          paste0(
            path.out,
            target.site[i1],
            "_allyear_stat_diurnal_seasonal.csv"
          ),
          row.names = F
        )
    } else{
      print(paste(
        "[Info] No historical threshold, skip diurnal-seaosnal check"
      ))

      diurseasonal.stat.all <- data.frame(matrix(
        ncol = 7,
        nrow = 0,
        dimnames = list(
          NULL,
          c(
            "year",
            "var_name",
            "lag	max_ccor",
            "wihtin_95per_range",
            "wihtin_Q1Q3_range",
            "all_constant",
            "status"
          )
        )
      ))

      if (output.stat)
        write.csv(
          diurseasonal.stat.all,
          paste0(
            path.out,
            target.site[i1],
            "_allyear_stat_diurnal_seasonal.csv"
          ),
          row.names = F
        )
    }
  }

  print("Diurnal-seasonal checks -- done")
  print(paste("################################################"))
  print(paste("                                                "))

}

if (sink.to.log)
  sink()

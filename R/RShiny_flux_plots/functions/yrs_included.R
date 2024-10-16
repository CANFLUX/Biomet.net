# Script to identify years available in the database
# By Sara Knox
# Created June, 2024

yrs_included <- 
  function(basepath,
           site,
           level) {
    
    # Find which years are available
    dir_yrs_sites <- dir_sites[grepl(site, dir_sites) == TRUE]
    yrs <- unique(str_extract(dir_yrs_sites, "\\d{4}"))
    
    # Check if level folder exists
    yrs_included <- c()
    for (i in 1:length(yrs)) {
      
      inpath <-
        paste(basepath,
              "/",
              as.character(yrs[i]),
              "/",
              site,
              "/",
              level,
              sep = "")
      
      if (dir.exists(inpath[1]) == TRUE) {
        yrs_included <- c(yrs_included,yrs[i])
      }
    }
    return(yrs_included)
  }



plot_datayear <- function(df,
                          var_set = NULL,
                          year_set = NULL) {
  data_avail <- df
  # If unspecified, obtain var_set through amf_variables()
  FP_var <- colnames(df)
  if (is.null(var_set)) {
    var_set <- FP_var
    
  } else{
    # check if var_set are valid variable names
    check_var <- var_set %in% FP_var
    if (all(!check_var)) {
      stop("No valid variable in var_set...")
    } else if (any(!check_var) & !all(!check_var)) {
      warning(paste(paste(var_set[which(!check_var)], collapse = ", "),
                    "not valid variable names"))
      var_set <- var_set[which(check_var)]
    }
  }
  
  #### subset data_aval
  var_year <- data_avail[colnames(data_avail) %in% var_set,]
  
  ## If unspecified, obtain year_set from all available years
  var_year_viz <- var_year
  
  #  return years with any available data
  year_ava <-
    unique(var_year_viz$year)
  
  if (is.null(year_set)) {
    year_set <- year_ava
  } else if (!is.numeric(year_set)) {
    stop("No valid year in year_set...")
  } else{
    # check if year_set are valid years
    check_year <- year_set %in% year_ava
    if (all(!check_year)) {
      stop("No valid year in year set")
    } else if (any(!check_year) & !all(!check_year)) {
      warning(paste(paste(year_set[which(!check_year)], collapse = ", "),
                    "have no data..."))
      year_set <- year_set[which(check_year)]
    }
  }
  # subset years
  var_year_viz <-
    var_year_viz[var_year_viz$year %in% year_set, ]
  
  # Remove non-numeric columns
  nums <- unlist(lapply(var_year_viz, is.numeric), use.names = FALSE)  
  var_year_viz <- var_year_viz[ , nums]
  
  ## prepare data for heatmap
  ### First create new dataframe for percentage of data by year
  var_year_coverage <- var_year_viz %>%
    group_by(year) %>%
    summarise(across(where(is.numeric), ~ round(sum(!is.na(.x))/n()*100)))
  
  ### Reorganize dataframe so that year is the column name and the row names represent each variable 
  var_year_coverage <- as.data.frame(t(var_year_coverage))
  
  # Rename columns
  colnames(var_year_coverage) <- as.character(year_set)
  
  # Remove the year row of data
  var_year_coverage <- var_year_coverage[!(row.names(var_year_coverage) %in% "year"), ]
  
  var_year_coverage <- (as.matrix(var_year_coverage))
  var_year_coverage[which(var_year_coverage == 0)] <- NA
  
  p <- heatmaply::heatmaply(
    var_year_coverage,
    dendrogram = "none",
    xlab = "",
    ylab = "",
    main = "",
    scale = "none",
    margins = c(60, 200, 20, 20),
    titleX = FALSE,
    plot_method = "plotly",
    hide_colorbar = FALSE,
    label_names = c("Variable", "Year", "Percentage"),
    fontsize_row = 10,
    fontsize_col = 10
  )
  
  return(p)
}

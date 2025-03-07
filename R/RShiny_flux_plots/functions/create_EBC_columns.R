# Function to create columns to assess energy balance closure 

create_EBC_columns <- function(data) {
  
  # Create data for available energy 
  # Find column indices where names match "G_1" or "G_1_1_1"
  g_index <- grep("^G_1(_1_1)?$", colnames(data))
  
  # If both exist, keep only "G_1"
  if ("G_1" %in% colnames(data)[g_index]) {
    g_index <- which(colnames(data) == "G_1")
  }
  
  # Find column indices where names match "NETRAD" or "NETRAD_1_1_1"
  netrad_index <- grep("^NETRAD(_1_1_1)?$", colnames(data))
  
  # Combine selected indices
  if (length(g_index) > 0){
    indices_AE <- c(netrad_index, g_index)
  } else {
    indices_AE <- netrad_index
  }
  
  # Create AE as sum of selected columns
  if (length(g_index) > 0){
    data$AE <- Reduce('-', data[, indices_AE])
  }else{
    data$AE <- data[, indices_AE]
  }
  
  # Dynamically rename AE column
  new_AE_name <- "AE"
  if ("G_1" %in% colnames(data) | "G_1_1_1" %in% colnames(data)) {
    new_AE_name <- paste0(new_AE_name, "_G")
  }
  if ("NETRAD" %in% colnames(data) | "NETRAD_1_1_1" %in% colnames(data)) {
    new_AE_name <- paste0(new_AE_name, "_NETRAD")
  }
  
  # Rename AE column
  colnames(data)[which(colnames(data) == "AE")] <- new_AE_name
  
  # Create data for turbulent fluxes (H_LE)
  H_index <- grep("^H_.*_uStar_orig$", colnames(data))
  LE_index <- grep("^LE_.*_uStar_orig$", colnames(data))
  
  # Combine selected indices
  indices_H_LE <- c(H_index, LE_index)
  
  # Create H_LE as sum of selected columns
  data$H_LE <- rowSums(data[, indices_H_LE], na.rm = FALSE)
  
  return(data)
}
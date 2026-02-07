na.median <-
  function(x) {
    ifelse(sum(!is.na(x)) >= 0.25 * min(length(x), 30),
           median(x, na.rm = T), NA)
  }
upp.bd <-
  function(x) {
    ifelse(sum(!is.na(x)) >= 0.25 * min(length(x), 30),
           quantile(x, probs = 0.75, na.rm = T),
           NA)
  }
low.bd <-
  function(x) {
    ifelse(sum(!is.na(x)) >= 0.25 * min(length(x), 30),
           quantile(x, probs = 0.25, na.rm = T),
           NA)
  }
upp.bd2 <-
  function(x) {
    ifelse(sum(!is.na(x)) >= 0.25 * min(length(x), 30),
           quantile(x, probs = 0.975, na.rm = T),
           NA)
  }
low.bd2 <-
  function(x) {
    ifelse(sum(!is.na(x)) >= 0.25 * min(length(x), 30),
           quantile(x, probs = 0.025, na.rm = T),
           NA)
  }

### Statistics removing NA
na.mean <-
  function(x) {
    ifelse(!is.nan(mean(x, na.rm = T)) &
             is.finite(mean(x, na.rm = T)), mean(x, na.rm = T), NA)
  }
na.min <-
  function(x) {
    ifelse(!is.nan(min(x.na.rm = T)), min(x.na.rm = T), NA)
  }
na.max <-
  function(x) {
    ifelse(!is.nan(max(x, na.rm = T)) &
             is.finite(max(x, na.rm = T)), max(x, na.rm = T), NA)
  }
na.sum <-
  function(x) {
    ifelse(!is.nan(sum(x, na.rm = T)) &
             is.finite(sum(x, na.rm = T)), sum(x, na.rm = T), NA)
  }

### determine NA and non-NA counts
sum.na <- function(x) {
  sum(is.na(x), na.rm = T)
}
sum.notna <- function(x) {
  sum(!is.na(x), na.rm = T)
}
sum.both.notna <- function(x, y){
  sum(!is.na(x) & !is.na(y), na.rm = T)
}
sum.three.notna <- function(x, y, z){
  sum(!is.na(x) & !is.na(y) & !is.na(z), na.rm = T)
}

## used to parse numbers within string
Numextract <- function(string) {
  unlist(regmatches(string, gregexpr(
    "[[:digit:]]+\\.*[[:digit:]]*", string
  )))
}

get.first <-
  function(x) {
    x[1]
  }

get.last <-
  function(x) {
    x[length(x)]
  }

count.non.zero <-
  function(x, get.col){
    sum(x[, get.col] != 0)
  }

# Justify if input value is an integer
is.wholenumber <-
  function(x, tol = .Machine$double.eps ^ 0.5)
    abs(x - round(x)) < tol

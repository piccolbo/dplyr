#' Compute a lazy tbl.
#'
#' \code{compute} forces computation of lazy tbls, leaving data in the remote
#' source. \code{collect} also forces computation, but will bring data back into
#' an R data.frame (stored in a \code{\link{tbl_df}}). \code{collapse} doesn't
#' force computation, but collapses a complex tbl into a form that additional
#' restrictions can be placed on.
#'
#' @section Grouping
#'
#' \code{compute} and \code{collect} preserve grouping, \code{collapse} drops
#' it.
#'
#' @param x a data tbl
#' @param ... other arguments passed on to methods
#' @seealso \code{\link{copy_to}} which is the conceptual opposite: it
#'   takes a local data frame and makes it available to the remote source.
#' @export
#' @examples
#' batting <- tbl(lahman_sqlite(), "Batting")
#' remote <- select(filter(batting, year > 2010 && stint == 1), playerID:H)
#' remote2 <- collapse(remote)
#' cached <- compute(remote)
#' local  <- collect(remote)
#'
#' # Collapse is used by summarise so you can add additional restrictions
#' # on the computed columns. This is analogous to the HAVING restriction
#' batting <- tbl(lahman_sqlite(), "Batting")
#' players <- group_by(batting, PlayerID)
#' stints <- summarise(players, n = n())
#' compute(filter(stints, n > 10L))
compute <- function(x, name = random_table_name(), ...) {
  UseMethod("compute")
}

#' @export
#' @rdname compute
collect <- function(x, ...) {
  UseMethod("collect")
}

#' @export
#' @rdname compute
collapse <- function(x, ...) {
  UseMethod("collapse")
}

# Methods ---------------------------------------------------------------------

#' @S3method collapse tbl_sql
collapse.tbl_sql <- function(x, ...) {
  tbl(x$src, x$query$sql)
}

#' @S3method compute tbl_sql
compute.tbl_sql <- function(x, name = random_table_name(), ...) {
  x$query$save_into(name)
  update(tbl(x$src, name), group_by = groups(x))
}

#' @S3method collect tbl_sql
collect.tbl_sql <- function(x, ...) {
  grouped_df(x$query$fetch(), groups(x))
}


#' @S3method collapse tbl_df
collapse.tbl_df <- function(x, ...) x
#' @S3method collapse tbl_dt
collapse.tbl_dt <- function(x, ...) x
#' @S3method compute tbl_df
compute.tbl_df <- function(x, ...) x
#' @S3method compute tbl_dt
compute.tbl_dt <- function(x, ...) x
#' @S3method collect tbl_df
collect.tbl_df <- function(x, ...) x
#' @S3method collect tbl_dt
collect.tbl_dt <- function(x, ...) x

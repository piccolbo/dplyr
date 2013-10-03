#' SQL escaping.
#'
#' These functions are critical when writing functions that translate R
#' functions to sql functions. Typically a conversion function should escape
#' all it's inputs and return an sql object.
#'
#' @param ... Character vectors that will be combined into a single SQL
#'   expression. \code{ident} flags its input as a identifier, to ensure that
#'   it gets the correct quoting.
#' @param x An object to escape. Existing sql vectors will be left as is,
#'   character vectors are escaped with single quotes, numeric vectors have
#'   trailing \code{.0} added if they're whole numbers, identifiers are 
#'   escaped with double quotes.
#' @param parens,collapse Controls behaviour when multiple values are supplied.
#'   \code{parens} should be a logical flag, or if \code{NA}, will wrap in 
#'   parens if length > 1.
#' 
#'   Default behaviour: lists are always wrapped in parens and separated by 
#'   commas, identifiers are separated by commas and never wrapped, 
#'   atomic vectors are separated by spaces and wrapped in parens if needed.
#' @keywords internal
#' @export
#' @examples
#' # Doubles vs. integers
#' escape(1:5)
#' escape(c(1, 5.4))
#' 
#' # String vs known sql vs. sql identifier 
#' escape("X")
#' escape(sql("X"))
#' escape(ident("X"))
#' 
#' # Escaping is idempotent
#' escape("X")
#' escape(escape("X"))
#' escape(escape(escape("X")))
#'
#' # You can use these functions to make your own R wrappers for SQL functions.
#' # The following is a more sophisticated version of round that have more
#' # informative variable names and if present, checks that the second argument
#' # is a number.
#' sql_round <- function(x, dp = NULL) {
#'   x <- escape(x)
#'   if (is.null(dp)) return(sql("ROUND(", x, ")"))
#'
#'   stopifnot(is.numeric(dp), length(dp) == 1)
#'   sql("ROUND(", x, ", ", dp, ")")
#' }
#' sql_round(sql("X"), 5)
#'
#' rounder <- sql_variant(round = sql_round)
#' to_sql(round(X), rounder)
#' to_sql(round(X, 5), rounder)
#' \dontrun{to_sql(round(X, "a"), rounder)}
sql <- function(x) {
  structure(x, class = c("sql", "character"))
}

#' @export 
#' @rdname sql
ident <- function(...) {
  x <- c(...)
  if (is.null(x)) return()
  structure(x, class = c("ident", "sql", "character"))
}

#' @S3method c sql
c.sql <- function(..., drop_null = FALSE) {
  input <- list(...)
  if (drop_null) input <- compact(input)
  
  out <- unlist(lapply(input, escape, collapse = NULL))
  sql(out)
}

#' @S3method unique sql
unique.sql <- function(x, ...) {
  sql(NextMethod())
}


setOldClass(c("sql", "character"))
setOldClass(c("ident", "sql", "character"))

#' @rdname sql
#' @export
is.sql <- function(x) inherits(x, "sql")

#' @rdname sql
#' @export
is.ident <- function(x) inherits(x, "ident")


#' @S3method print sql
print.sql <- function(x, ...) cat(format(x, ...), sep = "\n")
#' @S3method format sql
format.sql <- function(x, ...) paste0("<SQL> ", x)

#' @rdname sql
#' @export
escape <- function(x, parens = NA, collapse = " ", con = NULL) {
  UseMethod("escape")
}

#' @S3method escape ident
escape.ident <- function(x, parens = FALSE, collapse = ", ", con = NULL) {
  y <- escape_ident(con, x)
  sql_vector(names_to_as(y, con), parens, collapse)
}

#' @S3method escape logical
escape.logical <- function(x, parens = NA, collapse = ", ", con = NULL) {
  x <- as.character(x)
  x[is.na(x)] <- "NULL"
  sql_vector(x, parens, collapse)
}

#' @S3method escape factor
escape.factor <- function(x, parens = NA, collapse = ", ", con = NULL) {
  x <- as.character(x)
  escape.character(x, parens = parens, collapse = collapse, con = con)
}

#' @S3method escape Date
escape.Date <- function(x, parens = NA, collapse = ", ", con = NULL) {
  x <- as.character(x)
  escape.character(x, parens = parens, collapse = collapse, con = con)
}

#' @S3method escape character
escape.character <- function(x, parens = NA, collapse = ", ", con = NULL) {
  sql_vector(escape_string(con, x), parens, collapse, con = con)
}

#' @S3method escape double
escape.double <- function(x, parens = NA, collapse = ", ", con = NULL) {
  missing <- is.na(x)
  x <- ifelse(is.wholenumber(x), sprintf("%.1f", x), as.character(x))
  x[missing] <- "NULL"
  
  sql_vector(x, parens, collapse)
}

#' @S3method escape integer
escape.integer <- function(x, parens = NA, collapse = ", ", con = NULL) {
  x[is.na(x)] <- "NULL"
  sql_vector(x, parens, collapse)
}

#' @S3method escape NULL
escape.NULL <- function(x, parens = NA, collapse = " ", con = NULL) {
  sql("NULL")
}

#' @S3method escape sql
escape.sql <- function(x, parens = NULL, collapse = NULL, con = NULL) {
  sql_vector(x, isTRUE(parens), collapse, con = con)
}

#' @S3method escape list
escape.list <- function(x, parens = TRUE, collapse = ", ", con = NULL) {
  pieces <- vapply(x, escape, character(1), con = con)
  sql_vector(pieces, parens, collapse)
}

sql_vector <- function(x, parens = NA, collapse = " ", con = NULL) {
  if (is.na(parens)) {
    parens <- length(x) > 1L
  }
  
  x <- names_to_as(x, con = con)
  x <- paste(x, collapse = collapse)
  if (parens) x <- paste0("(", x, ")")
  sql(x)
}

names_to_as <- function(x, con = NULL) {
  names <- names2(x)
  as <- ifelse(names == '', '', paste0(' AS ', escape_ident(con, names)))
  
  paste0(x, as)
}


#' Build a SQL string.
#' 
#' This is a convenience function that should prevent sql injection attacks
#' (which in the context of dplyr are most likely to be accidental not
#' deliberate) by automatically escaping all expressions in the input, while
#' treating bare strings as sql. This is unlikely to prevent any serious
#' attack, but should make it unlikely that you produce invalid sql.
#' 
#' @param ... input to convert to SQL. Use \code{\link{sql}} to preserve
#'   user input as is (dangerous), and \code{\link{ident}} to label user
#'   input as sql identifiers (safe)
#' @param .env the environment in which to evalute the arguments. Should not
#'   be needed in typical use.
#' @export
#' @examples
#' build_sql("SELECT * FROM TABLE")
#' x <- "TABLE"
#' build_sql("SELECT * FROM ", x)
#' build_sql("SELECT * FROM ", ident(x))
#' build_sql("SELECT * FROM ", sql(x))
#' 
#' # http://xkcd.com/327/
#' name <- "Robert'); DROP TABLE Students;--"
#' build_sql("INSERT INTO Students (Name) VALUES (", name, ")")
build_sql <- function(..., .env = parent.frame(), con = NULL) {
  escape_expr <- function(x) {
    # If it's a string, leave it as is
    if (is.character(x)) return(x)
    
    val <- eval(x, .env)
    # Skip nulls, so you can use if statements like in paste
    if (is.null(val)) return("")
    
    escape(val, con = con)
  }
  
  pieces <- vapply(dots(...), escape_expr, character(1))
  sql(paste0(pieces, collapse = ""))
}

# Database specific methods ----------------------------------------------------

escape_string <- function(con, x) UseMethod("escape_string")
escape_string.default <- function(con, x) {
  sql_quote(x, "'")
}

escape_ident <- function(con, x) UseMethod("escape_ident")
escape_ident.default <- function(con, x) {
  sql_quote(x, '"')
}
escape_ident.MySQLConnection <- function(con, x) {
  sql_quote(x, "`")
}

sql_quote <- function(x, quote) {
  y <- gsub(quote, paste0(quote, quote), x, fixed = TRUE)
  y <- paste0(quote, y, quote)
  y[is.na(x)] <- "NULL"
  names(y) <- names(x)
  
  y
}

#' Read an R object in S3 by key
#'
#' Any type of object that can be serialized as an RDS file
#' is capable of being read using this interface.
#'
#' If you wish to read non-vanilla R objects, such as those
#' containing external pointers to C structures, see
#' \code{\link{s3normalize}}.
#'
#' @seealso \code{\link{s3store}}
#' @param name character. The key to grab from S3.
#' @param path character. The location of your S3 bucket as a prefix to \code{name},
#'    for example, \code{"s3://mybucket/"} or \code{"s3://mybucket/myprefix/"}.
#' @param cache logical. If true, use the local s3cache if available.
#'    If false, do not use cache. By default, \code{TRUE}. Note this will
#'    consume local disk space for objects that have been \code{\link{s3read}}.
#' @param serialize logical. If true, use \code{s3normalize} to serialize the model object.
#' @param ... Can be used internally to pass more arguments to \code{\link{s3.get}}.
#' @export
#' @examples
#' \dontrun{
#' s3store(c(1,2,3), "test123")
#' print(s3read("test123"))
#' # [1] 1 2 3
#'
#' s3store(function(x, y) { x + 2 * y }, "myfunc")
#' stopifnot(s3read("myfunc")(1, 2) == 5) # R can serialize closures!
#' }
s3read <- function(name, path = s3path(), cache = TRUE, serialize = TRUE, ...) {
  stopifnot(isTRUE(cache) || identical(cache, FALSE))
  ## If the user calls simply `s3read()`, we grab the latest uploaded
  ## key. Handy for shouting "Hey can you s3read the data!" from across
  ## the hall.
  if (missing(name)) {
    name <- grab_latest_file_in_s3_dir(path)
  }

  # All S3 paths need a slash at the end to work, but we don't need the user
  # to know that, so let's add a slash for them if they forget.
  last_character <- function(str) {
    substr(str, nchar(str), nchar(str))
  }
  if (last_character(path) != "/") { path <- paste0(path, "/") }

  s3key <- paste(path, name, sep = "")

  if (!isTRUE(cache) || is.null(getOption("s3mpi.cache"))) {
    value <- s3.get(s3key, ...)
  } else if (is.not_cached(value <- s3cache(s3key))) {
    value <- s3.get(s3key, ...)
    ## If the file system caching layer is enabled, store it to the file system
    ## before returning the value.
    s3cache(s3key, value)
  }
  if (isTRUE(serialize)) {
    s3normalize(value, TRUE)
  } else {
    value
  }
}

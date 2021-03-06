##' Connect to the Bloomberg server.
##' 
##' Create a the connection to Bloomberg by default on the local
##' machine or to a SAPI server.  When the connection is created the
##' jvm is also initialized.
##'
##' @param iface  The API interface to use.  Currently only \code{"Java"} supported
##' @param log.level the log4j logging level from \code{"finest"}, \code{"fine"}, \code{"info"}, \code{"warning"}
##' @param blpapi.jar.file explicit path the the Bloomberg java API
##'   file.  The code looks for the jar file in likely locations
##'   \code{/opt/local/BLP/APIv3/JavaAPI/blpjavaapi.jar} on unix and
##'   \code{C:\\blp\\API\\APIv3\\JavaAPI\\VERSION\\blpapi3.jar} on
##'   windows.
##' @param throw.ticker.errors throw an error for invalid tickers (default \code{TRUE})
##' @param jvm.params parameters passed to the jvm as a vector of strings (eg \code{jvm.params=c("-Xmx512m","-Xloggc:jvmgc.log")})
##' @param host host to connect to (for SAPI)
##' @param port port to connect to (for SAPI, default 8194)
##'
##' @seealso \code{\link{blpDisconnect}}
##'
##' @export
blpConnect <- function(iface="Java", log.level = "warning",
                       blpapi.jar.file = NULL, throw.ticker.errors = TRUE,
                       jvm.params = "-Xmx512m", host=NULL, port=NULL) {
  valid.interfaces <- c('Java')
  future.interfaces <- c('C')

  if (iface %in% future.interfaces) {
    stop(paste("Requested interface", iface, "is not yet implemented."))
  }

  if (!(iface %in% valid.interfaces)) {
    msg <- paste(
                 "Requsted interface",
                 iface,
                 "is not valid! Valid interfaces are ",
                 do.call("paste", as.list(valid.interfaces))
                 )
    stop(msg)
  }

  fn.name <- paste("blpConnect", iface, sep=".")
  fn.call <- call(fn.name, log.level, blpapi.jar.file, throw.ticker.errors, jvm.params, host, port)
  eval(fn.call)
}

##' Connect to the server via the Java API library.  JVM initialized as a side effect.
##'
##' @param log.level the log4j logging level; \code{"finest"}, \code{"fine"}, \code{"info"}, \code{"warning"}.
##' @param blpapi.jar.file explicit path the the Bloomberg java API file. 
##' @param throw.ticker.errors throw an error for invalid tickers (default \code{TRUE})
##' @param jvm.params parameters passed to the jvm as a vector of strings (for example \code{jvm.params=c("-Xmx512m", "-Xloggc:jvmgc.log")})
##' @param host host to connect to (for SAPI)
##' @param port port to connect to (for SAPI, default 8194)
##'
##' @seealso blpConnect
##' 
##' @keywords internal
blpConnect.Java <- function(log.level, blpapi.jar.file, throw.ticker.errors, jvm.params, host, port) {
  chatty <- log.level %in% c("fine","finest")

  if (chatty) {
    cat(R.version.string, "\n")
    cat("rJava Version", read.dcf(system.file("DESCRIPTION", package="rJava"))[1, "Version"], "\n")
    cat("RBloomberg Version", read.dcf(system.file("DESCRIPTION", package="RBloomberg"))[1, "Version"], "\n")
  }

  if (is.null(jvm.params)) {
    jinit_value <- try(.jinit())
  } else {
    if (chatty)
      cat("Using JVM parameters", jvm.params, "\n")
    jinit_value <- try(.jinit(parameters = jvm.params))
  }

  if (jinit_value == 0) {
    if (chatty) cat("Java environment initialized successfully.\n")
  } else if (class(jinit_value) == "try-error") {
    stop("Java environment not initialized. Please consult the rJava documentation. You may need to upgrade or install Java.")
  } else if (jinit_value < 0) {
    stop(paste("Error in creating Java environment. Status code", jinit_value))
  } else if (jinit_value > 0) {
    cat("Java environment started, but there may be some problems. Status code", jinit_value, "\n")
  } else {
    stop(paste("Should not be here. jinit_value is", jinit_value, "Please report this as a bug"))
  }

  if (is.null(blpapi.jar.file)) {
    if (.Platform$OS.type == "unix") {
      java_api_dir <- "/opt/local/BLP/APIv3/JavaAPI"
      api.filename <- "blpjavaapi.jar"
    } else {
      java_api_dir = "C:\\blp\\API\\APIv3\\JavaAPI"
      api.filename <- "blpapi3.jar"
    }
    if (chatty)
      cat("Looking for most recent",api.filename," file...\n")

    missing_java_api_dir_message = paste("Can't find", java_api_dir, "please confirm you have Bloomberg Version 3 Java API installed. If it's in a different location, please report this to RBloomberg package maintainer.")

    if (!file.exists(java_api_dir))
      stop(missing_java_api_dir_message)

    version.dir <- sort(list.files(java_api_dir, "^v", ignore.case=TRUE), decreasing=TRUE)[1]
    if (is.na(version.dir))
      blpapi.jar.file <- paste(java_api_dir, "lib", api.filename, sep=.Platform$file.sep)
    else
      blpapi.jar.file <- paste(java_api_dir, version.dir, "lib", "blpapi3.jar", sep=.Platform$file.sep)
    end

    if (!file.exists(blpapi.jar.file) && .Platform$OS.type == "windows"){
      blpapi.jar.file <- "C:\\blp\\API\\blpapi3.jar" # Last resort - Bloomberg website downloads get installed here.
    }
  }

  if (file.exists(blpapi.jar.file)) {
    .jaddClassPath(blpapi.jar.file)
  } else {
    stop(paste(api.filename,"file not found at", blpapi.jar.file, "please locate",api.filename," file and pass location including full path to blpConnect as blpapi.jar.file parameter. This might be a bug, if so please report it. Or try reinstalling the Java API from UPGR or WAPI pages."))
  }

  blpwrapper.jar.file = system.file("java", "blpwrapper.jar", package="RBloomberg")

  if (file.exists(blpwrapper.jar.file)) {
    .jaddClassPath(blpwrapper.jar.file)
  } else {
    stop(paste("blpwrapper jar file not found at", blpwrapper.jar.file, "please report this as a bug"))
  }

  java.logging.levels = J("java/util/logging/Level")

  java.log.level <- switch(log.level,
                           finest = java.logging.levels$FINEST,
                           fine = java.logging.levels$FINE,
                           info = java.logging.levels$INFO,
                           warning = java.logging.levels$WARNING,
                           stop(paste("log level ", log.level, "not recognized"))
                           )

  if (chatty)
    cat("Bloomberg API Version", J("com.bloomberglp.blpapi.VersionInfo")$versionString(), "\n")

  if (!is.null(host) || !is.null(port)) {
    if (is.null(host))
      host <- "127.0.0.1"
    if (is.null(port))
      port <- 8194L
    conn <- .jnew("org/findata/blpwrapper/Connection", java.log.level, host, port)
  } else {
    conn <- .jnew("org/findata/blpwrapper/Connection", java.log.level)
  }

  if (throw.ticker.errors) {
    throw.ticker.errors.java = .jnew("java/lang/Boolean", TRUE)$booleanValue()
  } else {
    throw.ticker.errors.java = .jnew("java/lang/Boolean", FALSE)$booleanValue()
  }

  conn$setThrowInvalidTickerError(throw.ticker.errors.java)



  return(conn)
}

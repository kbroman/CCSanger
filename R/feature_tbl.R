#' Summary of features
#'
#' Show count min and max of features by type
#'
#' @param object tbl of feature information from \code{\link{get_mgi_features}}
#' @param major if \code{TRUE} (default), only summarize genes and exons
#'
#' @return tbl of feature summaries by type
#'
#' @author Brian S Yandell, \email{brian.yandell@@wisc.edu}
#' @keywords utilities
#'
#' @method summary feature_tbl
#' @rdname feature_tbl
#' @export
#' @importFrom dplyr filter group_by summarize ungroup
summary.feature_tbl <- function(object, major=TRUE) {
  if(!nrow(object))
    return(NULL)

  if(major)
    object <- dplyr::filter(object,
                            type %in% c("exon","gene","pseudogene","pseudogenic_exon"))
  dplyr::ungroup(
    dplyr::summarize(
      dplyr::group_by(object, type),
      count = n(),
      min_Mbp = convert_bp(min(start), FALSE),
      max_Mbp = convert_bp(max(stop), FALSE)))
}
#' Subset of features
#'
#' @param x tbl of feature information from \code{\link{get_feature_tbl}}
#' @param start_val,stop_val start and stop positions for subset
#' @param ... additional parameters ignored
#'
#' @return tbl of feature summaries by type
#'
#' @author Brian S Yandell, \email{brian.yandell@@wisc.edu}
#' @keywords utilities
#'
#' @method subset feature_tbl
#' @rdname feature_tbl
#' @export
#' @importFrom dplyr filter
subset.feature_tbl <- function(x, start_val=0, stop_val=max(x$stop), ...) {
  x <- dplyr::filter(x,
                     start >= convert_bp(start_val),
                     stop <= convert_bp(stop_val))
  class(x) <- unique(c("feature_tbl", class(x)))
  x
}

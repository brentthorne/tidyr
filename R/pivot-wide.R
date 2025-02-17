#' Pivot data from long to wide
#
#' @description
#' `pivot_wider()` "widens" data, increasing the number of columns and
#' decreasing the number of rows. The inverse transformation is
#' [pivot_longer()].
#'
#' Learn more in `vignette("pivot")`.
#'
#' @details
#' `pivot_wider()` is an updated approach to [spread()], designed to be both
#' simpler to use and to handle more use cases. We recomend you use
#' `pivot_wider()` for new code; `spread()` isn't going away but is no longer
#' under active development.
#'
#' @inheritParams pivot_longer
#' @param id_cols A set of columns that uniquely identifies each observation.
#'   Defaults to all columns in `data` except for the columns specified in
#'   `names_from` and `values_from`. Typically used when you have additional
#'   variables that is directly related.
#' @param names_from,values_from A pair of arguments describing which column
#'   (or columns) to get the name of the output column (`name_from`), and
#'   which column (or columns) to get the cell values from (`values_from`).
#'
#'   If `values_from` contains multiple values, the value will be added to the
#'   front of the output column.
#' @param names_sep If `names_from` or `values_from` contains multiple
#'   variables, this will be used to join their values together into a single
#'   string to use as a column name.
#' @param names_prefix String added to the start of every variable name. This is
#'   particularly useful if `names_from` is a numeric vector and you want to
#'   create syntactic variable names.
#' @param values_fill Optionally, a named list specifying what each `value`
#'   should be filled in with when missing.
#' @param values_fn Optionally, a named list providing a function that will be
#'   applied to the `value` in each cell in the output. You will typically
#'   use this when the combination of `id_cols` and `value` column does not
#'   uniquely identify an observation.
#' @export
#' @examples
#' # See vignette("pivot") for examples and explanation
#'
#' fish_encounters
#' fish_encounters %>%
#'   pivot_wider(names_from = station, values_from = seen)
#' # Fill in missing values
#' fish_encounters %>%
#'   pivot_wider(
#'     names_from = station,
#'     values_from = seen,
#'     values_fill = list(seen = 0)
#'   )
#'
#' # Generate column names from multiple variables
#' us_rent_income %>%
#'   pivot_wider(names_from = variable, values_from = c(estimate, moe))
#'
#' # Can perform aggregation with values_fn
#' warpbreaks <- as_tibble(warpbreaks[c("wool", "tension", "breaks")])
#' warpbreaks
#' warpbreaks %>%
#'   pivot_wider(
#'     names_from = wool,
#'     values_from = breaks,
#'     values_fn = list(breaks = mean)
#'   )
pivot_wider <- function(data,
                        id_cols = NULL,
                        names_from = name,
                        names_prefix = "",
                        names_sep = "_",
                        values_from = value,
                        values_fill = NULL,
                        values_fn = NULL,
                        spec = NULL) {

  if (is.null(spec)) {
    names_from <- enquo(names_from)
    values_from <- enquo(values_from)

    spec <- pivot_wider_spec(data,
      names_from = !!names_from,
      values_from = !!values_from,
      names_prefix = names_prefix,
      names_sep = names_sep
    )
  }
  spec <- check_spec(spec)

  values <- vec_unique(spec$.value)
  spec_cols <- c(names(spec)[-(1:2)], values)

  id_cols <- enquo(id_cols)
  if (!quo_is_null(id_cols)) {
    key_vars <- tidyselect::vars_select(names(data), !!id_cols)
  } else {
    key_vars <- names(data)
  }
  key_vars <- setdiff(key_vars, spec_cols)

  # Figure out rows in output
  df_rows <- data[key_vars]
  if (ncol(df_rows) == 0) {
    rows <- tibble(.rows = 1)
    row_id <- rep(1L, nrow(df_rows))
  } else {
    rows <- vec_unique(df_rows)
    row_id <- vec_match(df_rows, rows)
  }

  value_specs <- unname(split(spec, spec$.value))
  value_out <- vec_init(list(), length(value_specs))

  for (i in seq_along(value_out)) {
    spec_i <- value_specs[[i]]
    value <- spec_i$.value[[1]]
    val <- data[[value]]

    cols <- data[names(spec_i)[-(1:2)]]
    col_id <- vec_match(cols, spec_i[-(1:2)])
    val_id <- data.frame(row = row_id, col = col_id)

    dedup <- vals_dedup(
      key = val_id,
      val = val,
      value = value,
      summarize = values_fn[[value]]
    )
    val_id <- dedup$key
    val <- dedup$val

    nrow <- nrow(rows)
    ncol <- nrow(spec_i)

    fill <- values_fill[[value]]
    if (is.null(fill)) {
      out <- vec_init(val, nrow * ncol)
    } else {
      stopifnot(vec_size(fill) == 1)
      fill <- vec_cast(fill, val)
      out <- vec_repeat(fill, nrow * ncol)
    }
    vec_slice(out, val_id$row + nrow * (val_id$col - 1L)) <- val

    value_out[[i]] <- wrap_vec(out, spec_i$.name)
  }

  out <- vec_cbind(rows, !!!value_out)

  # recreate desired column order
  # https://github.com/r-lib/vctrs/issues/227
  if (all(spec$.name %in% names(out))) {
    out <- out[c(names(rows), spec$.name)]
  }
  out
}

#' @export
#' @rdname pivot_wider
pivot_wider_spec <- function(data,
                             names_from = name,
                             values_from = value,
                             names_prefix = "",
                             names_sep = "_") {
  names_from <- tidyselect::vars_select(names(data), !!enquo(names_from))
  values_from <- tidyselect::vars_select(names(data), !!enquo(values_from))

  row_ids <- vec_unique(data[names_from])
  row_names <- exec(paste, !!!row_ids, sep = names_sep)

  out <- tibble(
    .name = paste0(names_prefix, row_names)
  )

  if (length(values_from) == 1) {
    out$.value <- values_from
  } else {
    out <- vec_repeat(out, times = vec_size(values_from))
    out$.value <- vec_repeat(values_from, each = vec_size(row_ids))
    out$.name <- paste0(out$.value, names_sep, out$.name)

    row_ids <- vec_repeat(row_ids, times = vec_size(values_from))
  }

  vec_cbind(out, row_ids)
}

# quiet R CMD check
name <- value <- NULL

# Helpers -----------------------------------------------------------------

# Not a great name as it now also casts
vals_dedup <- function(key, val, value, summarize = NULL) {

  if (is.null(summarize)) {
    if (!vec_duplicate_any(key)) {
      return(list(key = key, val = val))
    }

    warn(glue::glue(
      "Values in `{value}` are not uniquely identified; output will contain list-cols.\n",
      "* Use `values_fn = list({value} = list)` to suppress this warning.\n",
      "* Use `values_fn = list({value} = length)` to identify where the duplicates arise\n",
      "* Use `values_fn = list({value} = summary_fun)` to summarise duplicates"
    ))
  }

  out <- vec_split(val, key)
  if (!is.null(summarize) && !identical(summarize, list)) {
    summarize <- as_function(summarize)
    # This is only correct if `values_collapse` always returns a single value
    # Needs https://github.com/r-lib/vctrs/issues/183
    out$val <- vec_c(!!!map(out$val, summarize))
  }

  out
}

# Wrap a "rectangular" vector into a data frame
wrap_vec <- function(vec, names) {
  ncol <- length(names)
  nrow <- length(vec) / ncol
  out <- set_names(vec_init(list(), ncol), names)
  for (i in 1:ncol) {
    out[[i]] <- vec_slice(vec, ((i - 1) * nrow + 1):(i * nrow))
  }

  as_tibble(out)
}

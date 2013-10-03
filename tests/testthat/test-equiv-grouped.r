context("Equivalence (grouped)")

players <- players_tbls()

test_that("group size the same regardless of data tbl", {
  gs_df <- group_size(players$df)
  gs_dt <- group_size(players$df)
  gs_db1 <- group_size(players$sqlite)
  gs_db2 <- group_size(players$postgres)
  
  expect_equal(gs_dt, gs_df)
  expect_equal(gs_db1, gs_df)
  expect_equal(gs_db2, gs_df)
})

test_that("n the same regardless of tbl", {
  count_df <- summarise(players$df, count = n())
  count_dt <- ungroup(summarise(players$dt, count = n()))
  count_db1 <- summarise(players$sqlite, count = n())
  count_db2 <- summarise(players$sqlite, count = n())
  
  expect_equal(count_dt$n, count_df$n)
  expect_equal(count_db1$n, count_df$n)
  expect_equal(count_db2$n, count_df$n)
})

test_that("filter the same regardless of tbl", {
  filter_df <- strip(filter(players$df, AB == max(AB, -Inf, na.rm = TRUE)))
  filter_dt <- strip(filter(players$dt, AB == max(AB, -Inf, na.rm = TRUE)))
  # sqlite doesn't supported windowed filters
  filter_db2 <- strip(filter(players$postgres, AB == max(AB)))
  
  expect_equivalent(filter_dt, filter_df)
  expect_equivalent(filter_db2, filter_df)
})

test_that("arrange the same regardless of tbl (after removing missing values)", {
  arrange1 <- function(tbl) {
    tbl <- select(tbl, playerID, yearID, AB, G)
    out <- strip(arrange(tbl, AB, desc(G), yearID))
    out[!is.na(out$AB) & !is.na(out$G), ]
  }
  
  arranged <- lapply(players, arrange1)
  
  expect_equivalent(arranged$dt, arranged$df)
  expect_equivalent(arranged$sqlite, arranged$df)
  expect_equivalent(arranged$postgres, arranged$df)
})

test_that("mutate the same regardless of tbl", {
  mutate1 <- function(tbl) {
    tbl <- select(tbl, playerID, yearID)
    out <- strip(mutate(tbl, cyear = yearID - min(yearID) + 1))
    out[order(out$playerID, out$yearID), ]
  }

  mutated <- lapply(players[c("df", "dt", "postgres")], mutate1)
  
  expect_equivalent(mutated$dt, mutated$df)
  expect_equivalent(mutated$postgres, mutated$df)
})

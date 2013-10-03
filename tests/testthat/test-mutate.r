context("Mutate")

test_that("repeated outputs applied progressively (data frame)", {
  df <- data.frame(x = 1)
  out <- mutate(df, z = x + 1, z = z + 1)  
  
  expect_equal(nrow(out), 1)
  expect_equal(ncol(out), 2)
  
  expect_equal(out$z, 3)
})

test_that("repeated outputs applied progressively (grouped_df)", {
  df <- data.frame(x = c(1, 1), y = 1:2)
  ds <- group_by(df, y)
  out <- mutate(ds, z = x + 1, z = z + 1)  
  
  expect_equal(nrow(out), 2)
  expect_equal(ncol(out), 3)
  
  expect_equal(out$z, c(3L, 3L))
})

df <- data.frame(x = 1:10, y = 6:15)
tbls <- clone_tbls(df)

test_that("two mutates equivalent to one", {
  exp <- strip(mutate(df, x2 = x * 2, y4 = y * 4))
  
  expect_equal(strip(mutate(mutate(tbls$df, x2 = x * 2), y4 = y * 4)), exp)
  expect_equal(strip(mutate(mutate(tbls$dt, x2 = x * 2), y4 = y * 4)), exp)
  expect_equal(strip(mutate(mutate(tbls$sqlite, x2 = x * 2), y4 = y * 4)), exp)
})

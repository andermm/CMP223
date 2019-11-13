  library(DoE.base)
  set.seed(0)
  cmp223 <- fac.design(factor.names = list(
    apps = c("bt.D.x", "ep.D.x", "cg.D.x", "mg.D.x", "lu.D.x", "sp.D.x", "is.D.x", "ft.D.x"),
    interface = c("eth", "ib", "openib")),
    replications=30,
    randomize=TRUE)
    print(cmp223)
  
  write.table(cmp223, file = "experimental_project_npb_exec.csv",
                sep=";"
  )
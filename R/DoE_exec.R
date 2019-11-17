  library(DoE.base)
  set.seed(0)
  cmp223 <- fac.design(factor.names = list(
    apps = c("bt.D.x", "ep.D.x", "cg.D.x", "mg.D.x", "lu.D.x", "sp.D.x", "is.D.x", "ft.D.x", "imb_memory", "imb_CPU", 
      "ondes3d"),
    interface = c("eth", "ib", "ipoib")),
    replications=30,
    randomize=TRUE)
    print(cmp223)
  
  write.table(cmp223, file = "experimental_project_exec.csv",
                sep=";"
  )
  library(DoE.base)
  set.seed(0)
  cmp223_exec <- fac.design(factor.names = list(
    apps = c("bt.D.x", "ep.D.x", "cg.D.x", "mg.D.x", "lu.D.x", "sp.D.x", "is.D.x", "ft.D.x", "imb_memory", "imb_CPU", 
      "ondes3d", "intel", "Alya.x"),
    interface = c("eth", "ib", "ipoib")),
    replications=30,
    randomize=TRUE)
    print(cmp223_exec)
  
  write.table(cmp223_exec, file = "experimental_project_exec.csv",
                sep=","
  )
  
  set.seed(0)
  cmp223_charac <- fac.design(factor.names = list(
    apps = c("bt.D.x", "ep.D.x", "cg.D.x", "mg.D.x", "lu.D.x", "sp.D.x", "is.D.x", "ft.D.x", "imb_memory", "imb_CPU", 
             "ondes3d", "Alya.x"),
    interface = c("eth", "ib", "ipoib")),
    replications=1,
    randomize=TRUE)
  print(cmp223_charac)
  
  write.table(cmp223_charac, file = "experimental_project_charac.csv",
              sep=","
  )
  

packages <- c("dplyr", "tidyr", "optparse", "data.table", "RSQLite", "RColorBrewer")


for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org", dependencies = TRUE)
  }
}

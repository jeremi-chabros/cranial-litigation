library(usmap)
library(ggplot2)

df <- read.csv("mapvals_award.csv")

# plt <- plot_usmap(data = df, values = "num_cases", color = "#000000") +
#   scale_fill_continuous(name = "Number of cases", label = scales::comma, low = "white", high = "red") +
#   theme(legend.position = "right")

# ggsave("my_plot.png", plot = plt, dpi = 300)


centroid_labels <- usmapdata::centroid_labels("states")
data_labels <- merge(centroid_labels, df, by = "abbr")

plt <- plot_usmap(data = df, values = "num_cases", color = "#000000") +
  scale_fill_continuous(name = "Award [USD]", label = scales::comma, low = "white", high = "red") +
  theme(legend.position = "right")
ggsave("my_plot_award.png", plot = plt, dpi = 300)

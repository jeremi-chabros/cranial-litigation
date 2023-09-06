using Plots, CSV, DataFrames, Statistics, StatsBase, Measures, StatsPlots, HypothesisTests, GLM
theme(:ggplot2)
# theme(:wong2)

df = DataFrame(CSV.File("Final.csv"))

filter!(Symbol("Exclusion Category (0 = include; 1 = exclude; 2 = more information needed; 3 = non-neuro spec. but crani NSYG related)") => ==("0"), df)

begin
    using DataFrames, GLM, Plots, StatsBase

    # Assume df is your DataFrame

    # Filter data
    tm = filter(row -> row[:Year] != "Unknown" && row[:Award] != "Unknown" && row[:Award] != "0.00", df)
    tm.Year = parse.(Int, tm.Year)
    tm.Award = parse.(Float64, tm.Award)

    # Separate data based on the value of :Verdict
    tm_plaintiff = filter(row -> row[:Verdict] == "Plaintiff", tm)
    tm_settlement = filter(row -> row[:Verdict] == "Settlement", tm)

    # Scatter plot for "Plaintiff" data
    scatter(tm_plaintiff.Year, tm_plaintiff.Award, yscale=:log10, color=:blue, legend=:bottomright, xlabel="Year", ylabel="Award [USD]", tickfontsize=14, labelfontsize=14, label="Plaintiff Points")

    # Scatter plot for "Settlement" data
    scatter!(tm_settlement.Year, tm_settlement.Award, yscale=:log10, color=:red, legend=:bottomright, label="Settlement Points")

    # Fit linear models and plot for each group
    for (data, verdict, color) in [(tm_plaintiff, "Plaintiff", :blue), (tm_settlement, "Settlement", :red)]
        lm_res = lm(@formula(log(Award) ~ Year), data)

        y_pred = exp.(predict(lm_res))

        residuals = log.(data.Award) .- predict(lm_res)
        std_residual = std(residuals)

        upper_bound = exp.(predict(lm_res) .+ std_residual)
        lower_bound = exp.(predict(lm_res) .- std_residual)

        plot!(data.Year, y_pred, color=color, linewidth=2, label="$verdict Trend", dpi=300)
    end

    savefig("trends.png")
    # Show the plot
    display(current())

end

h = 0.157439
round((exp(h) - 1) * 100, digits=2)

begin
    using DataFrames, GLM, Plots, StatsBase, Random

    # Assume df is your DataFrame

    # Filter data
    
    tm = filter(row -> row[:Year] != "Unknown" && row[:Award] != "Unknown" && row[:Award] != "0.00", df)
    tm = filter(:Subspecialty => !=("Unknown"), tm)
    tm.Year = parse.(Int, tm.Year)
    tm.Award = parse.(Float64, tm.Award)

    # Generate a list of unique subspecialties
    unique_subspecialties = unique(tm[!, :Subspecialty])

    # Generate random colors for each subspecialty (you can also specify your own)
    colors = rand(length(unique_subspecialties))

    # Initialize plot
    p = scatter(legend=:bottomright, yscale=:log10, xlabel="Year", ylabel="Award [USD]", tickfontsize=14, labelfontsize=14)

    for (idx, subspecialty) in enumerate(unique_subspecialties)
        # Filter data for the specific subspecialty
        tm_sub = filter(row -> row[:Subspecialty] == subspecialty, tm)

        # Skip if not enough data points for fitting
        if nrow(tm_sub) < 2
            continue
        end

        # Scatter plot for this subspecialty
        scatter!(tm_sub.Year, tm_sub.Award, label="$subspecialty Points", labels="")

        # Fit a linear model to the log-transformed y-values for this subspecialty
        lm_res = lm(@formula(log(Award) ~ Year), tm_sub)

        # Generate the predicted y-values based on the model
        y_pred = exp.(predict(lm_res))

        # Calculate the residuals and standard deviation
        residuals = log.(tm_sub.Award) .- predict(lm_res)
        std_residual = std(residuals)

        # Calculate the upper and lower bounds for the ribbon
        upper_bound = exp.(predict(lm_res) .+ std_residual)
        lower_bound = exp.(predict(lm_res) .- std_residual)

        # Plot the trend line with uncertainty ribbon
        plot!(tm_sub.Year, y_pred, linewidth=2, label="$subspecialty Trend", dpi=300)
    end
    savefig("trend_by_specialty.png")
    # Show the plot
    display(p)

end


function droppedvals(df::DataFrame, column::Symbol, val_to_drop)
    return filter(row -> row[column] != val_to_drop, df)
end

# df = DataFrame(CSV.File("litig_final.csv"))
# df = droppedvals(df, :ExclusionCategory, 1)

begin
    ncases = length(df.Verdict)
    counts = countmap(df.Verdict)
    sorted_keys = sort(collect(keys(counts)), by=key -> counts[key], rev=true)
    sorted_values = [round(counts[key] / ncases, digits=2) for key in sorted_keys]
    # sorted_values = [counts[key] for key in sorted_keys]

    # Generate the bar plot
    p = plot(sorted_keys, sorted_values, color=:orange, seriestype=:bar, legend=false, dpi=300, size=(1000, 600), bottom_margin=20mm, leftmargin=5mm, topmargin=5mm,
        xlabel="Verdict", ylabel="Number of cases", xrotation=45)
    # Add the numbers on top of each bar using annotate
    annotate!([(i - 0.5, v + maximum(values(sorted_values)) * 0.02, text("n = $v", :center, 8)) for (i, v) in enumerate(values(sorted_values))])
    display(p)
    savefig(p, "Plots/verdicts.png")
end

pie(sorted_keys, sorted_values, dpi=300, size=(500, 500))

# Litigation category by subspecialty
begin
    df_d = droppedvals(df, :Subspecialty, "N/A")
    df_d = droppedvals(df_d, :Category, "N/A")
    filter!(:Subspecialty => !=("Unknown"), df_d)
    filter!(:Category => !=("Unknown"), df_d)
    grouped = groupby(df_d, [:Subspecialty, :Category])
    counts = combine(grouped, nrow => :Count)
    wide_format = unstack(counts, :Subspecialty, :Category, :Count)
    p = groupedbar(counts.Subspecialty, counts.Count, group=counts.Category, xrotation=45, dpi=300, size=(1000, 600), margin=10mm,
        xlabel="Subspecialty", ylabel="Number of cases", legend=:topleft, tickfontsize=12, bottommargin=15mm, ticksfontsize=12, labelfontsize=12)
    savefig(p, "Plots/by_subspecialty.png")
    p
end

# Litigation category by subspecialty as percentage
begin
    totals = combine(groupby(df_d, :Subspecialty), nrow => :Total)
    counts_with_total = leftjoin(counts, totals, on=:Subspecialty)
    counts_with_total[!, :Percentage] = counts_with_total.Count ./ counts_with_total.Total .* 100
    p = groupedbar(counts_with_total.Subspecialty, counts_with_total.Percentage, group=counts_with_total.Category, legend=:topright, xlabel="Subspecialty", ylabel="Percentage of cases (%)",
        xrotation=45, dpi=300, size=(1000, 600), margin=10mm, tickfontsize=12, bottommargin=15mm, ticksfontsize=12, labelfontsize=12)
    savefig("Plots/by_subspecialty_pct.png")
    p
end

# Verdict by litigation category
begin
    df_d = filter(:Verdict => !=("Unknown"), df)
    filter!(:Category => !=("Unknown"), df_d)

    grouped = groupby(df_d, [:Verdict, :Category])
    counts = combine(grouped, nrow => :Count)
    wide_format = unstack(counts, :Verdict, :Category, :Count)
    p = groupedbar(counts.Category, counts.Count, group=counts.Verdict, xrotation=45, dpi=300, size=(1000, 600), margin=10mm,
        xlabel="Verdict", ylabel="Number of cases", legend=:topleft)
    savefig(p, "Plots/by_verdict.png")
    p
end

# Verdict by litigation category as percentage
begin
    totals = combine(groupby(df_d, :Category), nrow => :Total)
    counts_with_total = leftjoin(counts, totals, on=:Category)
    counts_with_total[!, :Percentage] = counts_with_total.Count ./ counts_with_total.Total .* 100
    p = groupedbar(counts_with_total.Category, counts_with_total.Percentage, group=counts_with_total.Verdict, legend=:topright, xlabel="Subspecialty", ylabel="Percentage of cases (%)",
        xrotation=45, dpi=300, size=(1000, 600), margin=10mm, tickfontsize=12, bottommargin=15mm, ticksfontsize=12, labelfontsize=12)
    savefig("Plots/by_verdict_pct.png")
    p
end

# Verdict by subspecialty
begin
    df_d = filter(:Verdict => !=("Unknown"), df)
    filter!(:Subspecialty => !=("Unknown"), df_d)

    grouped = groupby(df_d, [:Verdict, :Subspecialty])
    counts = combine(grouped, nrow => :Count)
    wide_format = unstack(counts, :Verdict, :Subspecialty, :Count)
    p = groupedbar(counts.Subspecialty, counts.Count, group=counts.Verdict, xrotation=45, dpi=300, size=(1000, 600), margin=10mm,
        xlabel="Verdict", ylabel="Number of cases", legend=:topleft)
    savefig(p, "Plots/verdict_by_specialty.png")
    p
end

# Verdict by subspecialty as percentage
begin
    totals = combine(groupby(df_d, :Subspecialty), nrow => :Total)
    counts_with_total = leftjoin(counts, totals, on=:Subspecialty)
    counts_with_total[!, :Percentage] = counts_with_total.Count ./ counts_with_total.Total .* 100
    p = groupedbar(counts_with_total.Subspecialty, counts_with_total.Percentage, group=counts_with_total.Verdict, legend=:topright, xlabel="Subspecialty", ylabel="Percentage of cases (%)",
        xrotation=45, dpi=300, size=(1000, 600), margin=10mm, tickfontsize=12, bottommargin=15mm, ticksfontsize=12, labelfontsize=12)
    savefig("Plots/verdict_by_specialty_pct.png")
    p
end

# Award by verdict
begin
    awards = filter(:Award => !=("Unknown"), df)
    awards.Award .= parse.(Float64, awards.Award)
    filter!(:Award => !=(0.0), awards)

    mean_awards = Dict()
    varq = :Verdict
    for k in unique(awards[!, :Verdict])
        subg = filter(:Verdict => ==(k), awards)
        mean_awards[k] = subg.Award
    end

    award_df = DataFrame()
    for (key, values) in mean_awards
        append!(award_df, DataFrame(:Category => fill(key, length(values)), :Value => values))
    end

    # p = boxplot(mean_awards, yaxis=:log10, legend=false, xrotation=45, xlabel="Verdict", ylabel="Award [USD]", dpi=300, size=(1000, 600), margin=10mm)
    p = @df award_df boxplot(string.(:Category), :Value, linewidth=2, yaxis=:log10, xlabel="Verdict", ylabel="Award [USD]",
        dpi=300, size=(600, 600), margin=10mm, legend=false, fill=:thermal, fillalpha=0.75)
    # @df award_df violin!(string.(:Category), :Value, linewidth=1, alpha=0.5)

    savefig("Plots/awards.png")
    p
end

# Award by litigation category
begin
    awards = filter(:Award => !=("Unknown"), df)
    filter!(:Category => !=("Unknown"), awards)
    awards.Award .= parse.(Float64, awards.Award)
    filter!(:Award => !=(0.0), awards)

    # Perform pairwise statistical tests
    categories = unique(awards.Category)
    n = length(categories)
    p_values = Dict()

    for i in 1:n
        for j in (i+1):n
            cat_i = awards[awards.Category.==categories[i], :]
            cat_j = awards[awards.Category.==categories[j], :]

            # Using Mann-Whitney U test as an example
            test_result = pvalue(MannWhitneyUTest(cat_i.Award, cat_j.Award))
            p_values[(categories[i], categories[j])] = test_result
        end
    end

    p = @df awards boxplot(string.(:Category), :Award, yaxis=:log10, fillalpha=0.75, linewidth=2, xrotation=45, size=(1000, 600), xlabel="", ylabel="Award (USD)", margin=10mm, leftmargin=20mm, bottommargin=20mm, legend=false,
        fill=:thermal, tickfontsize=14, labelfontsize=14)

    bars_info = []
    for ((cat1, cat2), p_val) in p_values
        x1 = findall(categories .== cat1)[1] - 0.5
        x2 = findall(categories .== cat2)[1] - 0.5
        barl = abs(x2 - x1)
        if p_val < 1
            push!(bars_info, (barl, x1, x2, p_val))
        end
    end

    sort!(bars_info, by=x -> x[1], rev=false)

    for (x, (barl, x1, x2, p_val)) in enumerate(bars_info)
        y1 = maximum(awards.Award) * 10^(0.15 * x)

        startext = ""
        if 0.01 <= p_val < 0.05
            startext = "*"
        elseif 0.001 <= p_val < 0.01
            startext = "**"
        elseif p_val < 0.001
            startext = "***"
        else
            continue
        end

        annotate!(p, [((x1 + x2) / 2, y1 * 10^(0.05), text(startext, 14, :center))])
        plot!([x1, x2], [y1, y1], seriestype=:shape, lw=2, linecolor=:black)
    end
    savefig("Plots/award_by_category.png")
    p
end

# Award by subspecialty
begin
    awards = filter(:Award => !=("Unknown"), df)
    filter!(:Subspecialty => !=("Unknown"), awards)
    awards.Award .= parse.(Float64, awards.Award)
    filter!(:Award => !=(0.0), awards)

    # Perform pairwise statistical tests
    categories = unique(awards.Subspecialty)
    n = length(categories)
    p_values = Dict()

    for i in 1:n
        for j in (i+1):n
            cat_i = awards[awards.Subspecialty.==categories[i], :]
            cat_j = awards[awards.Subspecialty.==categories[j], :]

            # Using Mann-Whitney U test as an example
            test_result = pvalue(MannWhitneyUTest(cat_i.Award, cat_j.Award))
            p_values[(categories[i], categories[j])] = test_result
        end
    end

    p = @df awards boxplot(string.(:Subspecialty), :Award, yaxis=:log10, fillalpha=0.75, linewidth=2, xrotation=45, size=(1000, 600), xlabel="", ylabel="Award (USD)", margin=10mm, leftmargin=20mm, bottommargin=20mm, legend=false,
        fill=:thermal, tickfontsize=14, labelfontsize=14)

    bars_info = []
    for ((cat1, cat2), p_val) in p_values
        x1 = findall(categories .== cat1)[1] - 0.5
        x2 = findall(categories .== cat2)[1] - 0.5
        barl = abs(x2 - x1)
        if p_val < 1
            push!(bars_info, (barl, x1, x2, p_val))
        end
    end

    sort!(bars_info, by=x -> x[1], rev=false)

    for (x, (barl, x1, x2, p_val)) in enumerate(bars_info)
        y1 = maximum(awards.Award) * 10^(0.15 * x)

        startext = ""
        if 0.01 <= p_val < 0.05
            startext = "*"
        elseif 0.001 <= p_val < 0.01
            startext = "**"
        elseif p_val < 0.001
            startext = "***"
        else
            continue
        end

        annotate!(p, [((x1 + x2) / 2, y1 * 10^(0.05), text(startext, 14, :center))])
        plot!([x1, x2], [y1, y1], seriestype=:shape, lw=2, linecolor=:black)
    end
    savefig("Plots/award_by_specialty.png")
    p
end

# Number of cases by state
begin
    bar(countmap(df.State), xticks=(0.5:length(unique(df.State)), unique(df.State)), xrotation=45, size=(1000, 500), bottommargin=10mm)

    dfstate = countmap(df.State)
    # numbystate = DataFrame(state=collect(keys(dfstate)), num_cases=collect(values(dfstate)))
    numbystate = DataFrame(state=collect(keys(dfstate)), abbr=collect(keys(dfstate)), num_cases=collect(values(dfstate)))

    CSV.write("mapvals.csv", numbystate)
end

# Award amount by state
begin
    bar(countmap(df.State), xticks=(0.5:length(unique(df.State)), unique(df.State)), xrotation=45, size=(1000, 500), bottommargin=10mm)
    dfstate = countmap(df.State)
    state_award = Dict(unique(df.State) .=> 0)
    # numbystate = DataFrame(state=collect(keys(dfstate)), num_cases=collect(values(dfstate)))
    numbystate = DataFrame(state=collect(keys(dfstate)), abbr=collect(keys(dfstate)), num_cases=collect(values(dfstate)))
    CSV.write("mapvals.csv", numbystate)
end

begin
    state_award = filter(:Award => !=("0.00"), df)
    filter!(:Award => !=("Unknown"), state_award)
    state_award.Award .= parse.(Float64, state_award.Award)
    state_award.State .= string.(state_award.State)

    dfstate = Dict()
    for state in df.State
        bystate = filter(:State => ==(state), state_award)
        dfstate[state] = mean(bystate.Award)
    end
    numbystate = DataFrame(state=collect(keys(dfstate)), abbr=collect(keys(dfstate)), num_cases=collect(values(dfstate)))
    CSV.write("mapvals_award.csv", numbystate)
end

# cases by year
begin
    byear = filter(:Year => !=("Unknown"), df)
    byear.Year .= parse.(Int, byear.Year)
    histogram(byear.Year, bins=1989:2023,
        xlabel="Year",
        ylabel="Number of cases",
        legend=false,
        dpi=300)
    savefig("Plots/cases_by_year.png")
end

# cases by x 
begin
    byear = filter(:Year => !=("Unknown"), df)
    byear.Year .= parse.(Int, byear.Year)
    histogram(byear.Year, nbins=1989:5:2023,
        xlabel="Year",
        ylabel="Number of cases",
        legend=false,
        dpi=300)
    savefig("Plots/cases_by_year_quartile.png")
end


begin
    vard = filter(:Subspecialty => !=("Unknown"), df)
    ncases = length(vard.Subspecialty)
    counts = countmap(vard.Subspecialty)
    sorted_keys = sort(collect(keys(counts)), by=key -> counts[key], rev=true)
    # sorted_values = [round(counts[key], digits=2) for key in sorted_keys]
    sorted_values = [counts[key] for key in sorted_keys]

    # Generate the bar plot
    p = plot(sorted_keys, sorted_values, color=:orange, seriestype=:bar, legend=false, dpi=300, size=(1000, 600), bottom_margin=20mm, leftmargin=5mm, topmargin=5mm,
        xlabel="", ylabel="Number of cases", xrotation=45, labelfontsize=14, tickfontsize=14)
    # Add the numbers on top of each bar using annotate
    annotate!([(i - 0.5, v + maximum(values(sorted_values)) * 0.02, text("n = $v", :center, 12)) for (i, v) in enumerate(values(sorted_values))])
    display(p)
    savefig(p, "Plots/subspec.png")
end


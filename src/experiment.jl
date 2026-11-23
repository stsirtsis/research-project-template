using Random
using JSON
using Statistics
using ArgParse

function compute(N, prob, rng)

    votes = zeros(Int, N)
    abstained = 0

    for i in 1:N
        if rand(rng) < prob
            abstained += 1
        else
            eligible = collect(setdiff(1:N, [i]))
            votes[rand(rng, eligible)] += 1
        end
    end

    return votes, abstained
end

# run the experiment for a single seed
function single_seed_experiment(rng, N, iterations, prob)

    # initialize results arrays
    abstained_results = zeros(Int, iterations)
    winner_results = zeros(Int, iterations)

    println("Computing...")
    flush(stdout)
    for i in 1:iterations
        # perform computation (now passing rng)
        votes, abstained = compute(N, prob, rng)

        # save the results
        abstained_results[i] = abstained
        winner_results[i] = argmax(votes)
    end

    # perform aggregation
    avg_num_abstained = mean(abstained_results)
    num_of_wins = zeros(Int, N)
    for val in winner_results
        num_of_wins[val] += 1
    end
    most_common_winner = argmax(num_of_wins)

    return Dict(
        "avg_num_abstained" => avg_num_abstained,
        "most_common_winner" => most_common_winner
    )
end

function experiment(args)

    # parse the command line arguments
    s = ArgParseSettings()
    @add_arg_table! s begin
        # the first three options are specified by the executor
        "--exp_name"
            help="Name of the experiment"
            required=true
            arg_type=String
        "--output_dir"
            help="Output directory"
            required=true
            arg_type=String
        "--output_filename"
            help="Output filename"
            required=true
            arg_type=String
        # the rest are experiment-specific
        "--N"
            help="Number of voters"
            required=true
            arg_type=Int
        "--iterations"
            help="Number of iterations"
            required=true
            arg_type=Int
        "--prob"
            help="Probability of abstaining"
            required=false
            default=0.1
            arg_type=Float64
        "--master_seed"
            help="The master seed for generating seeds"
            required=false
            default=42
            arg_type=Int
        "--num_seeds"
            help="Number of derived seeds (0 = use master_seed directly)"
            required=false
            default=0
            arg_type=Int
    end

    # parse the arguments
    parsed_args = parse_args(args, s)
    exp_name = parsed_args["exp_name"]
    output_dir = parsed_args["output_dir"]
    output_filename = parsed_args["output_filename"]
    N = parsed_args["N"]
    iterations = parsed_args["iterations"]
    prob = parsed_args["prob"]
    master_seed = parsed_args["master_seed"]
    num_seeds = parsed_args["num_seeds"]

    # make sure N>1
    if N < 2
        error("N must be greater than 1")
    end

    # determine seeds to use
    if num_seeds <= 0
        # single-seed mode: use master_seed directly
        seeds = [master_seed]
    else
        # multi-seed mode: derive seeds from master_seed
        master_rng = Random.Xoshiro(master_seed)
        seeds = rand(master_rng, UInt32, num_seeds)
    end

    # collect seed results
    seed_results = []
    for seed in seeds
        # initialize the random number generator
        rng = Xoshiro(seed)
        # run the experiment
        result = single_seed_experiment(rng, N, iterations, prob)
        result["seed"] = Int(seed)
        push!(seed_results, result)
    end

    # build flat output structure
    output = Dict(
        "exp_name" => exp_name,
        "N" => N,
        "iterations" => iterations,
        "prob" => prob,
        "master_seed" => master_seed,
        "num_seeds" => num_seeds,
        "seed_results" => seed_results
    )

    # create output directory
    # this is not done in the executor, so that we don't create output directories for parameter combinations that are scheduled on slurm but perhaps not valid
    mkpath(output_dir)

    println("Saving results...")
    flush(stdout)
    open(joinpath(output_dir, output_filename), "w") do f
        write(f, JSON.json(output, 2))
    end

    println("Done!")
    flush(stdout)
end

# uncomment the following line for testing
experiment(ARGS)

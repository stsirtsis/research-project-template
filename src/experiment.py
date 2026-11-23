import numpy as np
import click
import json
import logging
import os
import sys

from utils import set_seeds

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', stream=sys.stdout)
logger = logging.getLogger(__name__)

# convert numpy types to native python types
def convert_to_native(obj):
    if isinstance(obj, np.generic):
        return obj.item()
    elif isinstance(obj, dict):
        return {convert_to_native(k): convert_to_native(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_to_native(i) for i in obj]
    else:
        return obj

# let the N people vote each other at random. with probability prob, a person does not vote
def compute(N, prob, rng):

    votes = np.zeros(N, dtype=int)
    abstained = 0
    for i in range(N):
        # if the random number is less than prob, the person does not vote
        if rng.random() < prob:
            abstained += 1
            continue
        else:
            # the person votes for another person (excluding i) at random
            eligible = set(range(N))
            eligible.remove(i)
            votes[rng.choice(list(eligible))] += 1

    return votes, abstained

# run the experiment for a single seed
def single_seed_experiment(rng, N, iterations, prob):

    # initialize the results arrays
    abstained_results = np.zeros(iterations, dtype=int)
    winner_results = np.zeros(iterations, dtype=int)

    logger.info('Computing...')
    for i in range(iterations):
        # perform computation
        votes, abstained = compute(N, prob, rng)

        # save the results
        abstained_results[i] = abstained
        winner_results[i] = np.argmax(votes)

    # perform aggregation
    avg_num_abstained = np.mean(abstained_results)
    most_common_winner = np.argmax(np.bincount(winner_results))

    return {
        'avg_num_abstained': avg_num_abstained,
        'most_common_winner': most_common_winner
    }


# comment the click commands for testing
@click.command()
# the first three options are specified by the executor
@click.option('--exp_name', type=str, required=True, help="name of the experiment")
@click.option('--output_dir', type=str, required=True, help="output directory")
@click.option('--output_filename', type=str, required=True, help="output filename")
# the rest are experiment-specific
@click.option('--N', type=int, required=True, help="number of voters")
@click.option('--iterations', type=int, required=True, help="rounds of voting")
@click.option('--prob', type=float, default=0.1, help="probability of abstaining")
@click.option('--master_seed', type=int, default=42, help="the master seed for generating seeds")
@click.option('--num_seeds', type=int, default=0, help="number of derived seeds (0 = use master_seed directly)")
def experiment(exp_name, output_dir, output_filename, n, iterations, prob, master_seed, num_seeds):

    N = n  # click doesn't accept upper case arguments

    # make sure N>1
    if N < 2:
        raise ValueError('N must be greater than 1')

    # set seeds for reproducibility
    set_seeds(master_seed)

    # determine seeds to use
    if num_seeds <= 0:
        # single-seed mode: use master_seed directly
        seeds = [master_seed]
    else:
        # multi-seed mode: derive seeds from master_seed
        master_rng = np.random.default_rng(seed=master_seed)
        seeds = master_rng.integers(low=0, high=2**32-1, size=num_seeds)

    # collect seed results
    seed_results = []
    for seed in seeds:
        # initialize the random number generator
        rng = np.random.default_rng(seed=seed)
        # run the experiment
        result = single_seed_experiment(rng, N, iterations, prob)
        result['seed'] = int(seed)
        seed_results.append(result)

    # build flat output structure
    output = {
        'exp_name': exp_name,
        'N': N,
        'iterations': iterations,
        'prob': prob,
        'master_seed': master_seed,
        'num_seeds': num_seeds,
        'seed_results': seed_results
    }

    logger.info('Converting to native Python types...')
    output = convert_to_native(output)

    # create output directory
    # this is not done in the executor, so that we don't create output directories for parameter combinations that are scheduled on slurm but perhaps not valid
    os.makedirs(output_dir, exist_ok=True)

    logger.info('Saving results...')
    with open(f'{output_dir}/{output_filename}', 'w') as f:
        json.dump(output, f, indent=2)

    logger.info('Done!')

    return


if __name__ == '__main__':
    # comment for testing
    experiment()
    # uncomment for testing
    # experiment('configs/experiment.json', 0)

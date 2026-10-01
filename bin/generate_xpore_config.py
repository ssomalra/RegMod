import argparse
from pathlib import Path
import yaml

def generate_xpore_config(samples, output, prior):
    """
    Generate an configuration file for xPore diffmod

    Parameters:
    samples (list): List of [condition, replicate, dataprep_dir] entries
    output (str): Path to output config.yml file
    prior (str): Path to the xPore prior model CSV file
    """

    data = {}

    for condition, replicate, dataprep_dir in samples:
        replicate_name = f"Rep{replicate}"

        if condition not in data:
            data[condition] = {}

        data[condition][replicate_name] = str(Path(dataprep_dir).resolve())

    config = {
        "data": data,
        "out": ".",
        "prior": str(Path(prior).resolve())
    }

    with open(output, 'w') as f:
        yaml.safe_dump(config, f, sort_keys=False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate xPore diffmod config file")
    parser.add_argument("--samples", nargs=3, action="append", required=True, metavar=("CONDITION", "REPLICATE", "DATAPREP_DIR"), help="List of [condition, replicate, xPore dataprep directory] entries")
    parser.add_argument("--output", required=True,help="Path to output xPore config.yml file")
    parser.add_argument("--prior", required=True, help="Path to the xPore prior model CSV file")
    args = parser.parse_args()

    generate_xpore_config(args.samples, args.output, args.prior)



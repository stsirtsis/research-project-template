"""
Download all models needed for experiments.
Models are cached in models/hf_cache/ under the project root.
If a model is already fully cached, the script does nothing.

NOTE: Modify the MODELS list below to include the models required for the project's specific experiments.
"""

import os
import pathlib

from huggingface_hub import scan_cache_dir, snapshot_download

_project_root = pathlib.Path(__file__).resolve().parent.parent
_project_cache = str(_project_root / "models" / "hf_cache")

# Add your model HF IDs here
MODELS = [
    "meta-llama/Llama-3.1-8B-Instruct",
]


def get_cached_repos(cache_dir):
    """Return repo_ids that are fully cached.

    huggingface_hub writes each file to a `.incomplete` blob during download and
    only renames it once finished, so a leftover `.incomplete` blob means the
    repo must be re-downloaded.
    """
    try:
        cache_info = scan_cache_dir(cache_dir)
    except Exception:
        return set()
    complete = set()
    for repo in cache_info.repos:
        if list(repo.repo_path.glob("blobs/*.incomplete")):
            print(
                f"[Model] {repo.repo_id} — found incomplete blob(s) from an interrupted download, will retry."
            )
        else:
            complete.add(repo.repo_id)
    return complete


def download(model_id, cache_dir):
    print(f"[Model] {model_id} — downloading...")
    try:
        path = snapshot_download(model_id, cache_dir=cache_dir)
        print(f"  -> Saved to {path}")
    except Exception as e:
        print(f"  -> ERROR: {e}")


def main():
    os.environ["HF_HUB_CACHE"] = _project_cache
    cached = get_cached_repos(_project_cache)
    for model_id in MODELS:
        if model_id in cached:
            print(f"[Model] {model_id} — already cached, skipping.")
        else:
            download(model_id, cache_dir=_project_cache)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
cleanup_test_data.py
Deletes the performance test realm created by seed_test_data.py.

Supports the same IAM backends as the seeder via IAM_PROVIDER:
  - ferriskey (default)
  - keycloak

Usage:
    uv run python scripts/cleanup_test_data.py
    uv run python scripts/cleanup_test_data.py --yes    # skip the confirmation prompt

Configuration is read from .env file or environment variables.
"""

import sys

from lib import load_config, print_success, print_warning
from seed_test_data import get_provider


def confirm_deletion(provider_name: str, base_url: str, realm: str) -> bool:
    print_warning(f"=== {provider_name} Performance Test Data Cleanup ===")
    print(f"Base URL: {base_url}")
    print(f"Realm to delete: {realm}")
    print()

    try:
        answer = input(f"Delete the '{realm}' realm and all its data? (y/N) ")
        return answer.strip().lower() in ("y", "yes")
    except (KeyboardInterrupt, EOFError):
        print()
        return False


def main() -> None:
    config = load_config()
    provider = get_provider(config.iam_provider, config)

    skip_prompt = "--yes" in sys.argv[1:] or "-y" in sys.argv[1:]
    if not skip_prompt and not confirm_deletion(provider.name, config.base_url, config.perf_realm):
        print("Cleanup cancelled.")
        sys.exit(0)

    print()
    print_warning("Step 1: Authenticating as admin...")
    admin_token = provider.get_admin_token()
    print()

    print_warning("Step 2: Deleting performance test realm...")
    if not provider.delete_realm(admin_token, config.perf_realm):
        sys.exit(1)
    print()

    print_success("=== Cleanup Complete ===")


if __name__ == "__main__":
    main()

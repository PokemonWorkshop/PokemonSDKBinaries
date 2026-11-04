#!/usr/bin/env python3
"""Download an authorized FMOD Studio API archive for CI builds.

The FMOD SDK archive is deliberately not stored in the repository or uploaded
as a workflow artifact. FMOD credentials must be supplied through environment
variables.

Required environment variables:
    FMOD_USER
    FMOD_PASSWORD
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import requests


LOGIN_URL = "https://www.fmod.com/api-login"
DOWNLOAD_LINK_URL = "https://www.fmod.com/api-get-download-link"

PLATFORMS = {
    "windows": ("Windows", "win-installer.exe"),
    "linux": ("Linux", "linux.tar.gz"),
    "macos": ("Mac", "mac-installer.dmg"),
}

REQUEST_TIMEOUT = 30
DOWNLOAD_TIMEOUT = 300


class FMODDownloadError(Exception):
    """Expected FMOD download failure safe to report in CI logs."""


def authenticate(user: str, password: str) -> str:
    print("Authenticating with FMOD...")

    try:
        response = requests.post(
            LOGIN_URL,
            auth=(user, password),
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as error:
        raise FMODDownloadError(
            f"FMOD authentication request failed ({type(error).__name__})."
        ) from error

    if response.status_code != 200:
        raise FMODDownloadError(
            f"FMOD authentication failed with HTTP {response.status_code}."
        )

    try:
        data = response.json()
    except requests.JSONDecodeError as error:
        raise FMODDownloadError(
            "FMOD authentication returned an invalid JSON response."
        ) from error

    token = data.get("token")
    if not isinstance(token, str) or not token:
        raise FMODDownloadError(
            "FMOD authentication response did not contain a token."
        )

    print("FMOD authentication succeeded.")
    return token


def get_download_url(
    *,
    token: str,
    user: str,
    platform_directory: str,
    filename: str,
) -> str:
    print("Requesting authorized FMOD download link...")

    try:
        response = requests.get(
            DOWNLOAD_LINK_URL,
            params={
                "path": f"files/fmodstudio/api/{platform_directory}/",
                "filename": filename,
                "user": user,
            },
            headers={
                "Authorization": f"Bearer {token}",
            },
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as error:
        raise FMODDownloadError(
            f"FMOD download-link request failed ({type(error).__name__})."
        ) from error

    if response.status_code != 200:
        raise FMODDownloadError(
            f"FMOD download-link request failed with HTTP {response.status_code}."
        )

    try:
        data = response.json()
    except requests.JSONDecodeError as error:
        raise FMODDownloadError(
            "FMOD download-link endpoint returned an invalid JSON response."
        ) from error

    download_url = data.get("url")
    if not isinstance(download_url, str) or not download_url.startswith("https://"):
        raise FMODDownloadError(
            "FMOD download-link response did not contain a valid HTTPS URL."
        )

    print("FMOD download link obtained.")
    return download_url


def download_archive(url: str, output: Path) -> None:
    print("Downloading FMOD SDK archive...")

    try:
        response = requests.get(
            url,
            stream=True,
            allow_redirects=True,
            timeout=DOWNLOAD_TIMEOUT,
        )
    except requests.RequestException as error:
        raise FMODDownloadError(
            f"FMOD archive download failed ({type(error).__name__})."
        ) from error

    if response.status_code != 200:
        response.close()
        raise FMODDownloadError(
            f"FMOD archive download failed with HTTP {response.status_code}."
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_output = output.with_name(f"{output.name}.tmp")

    try:
        with temporary_output.open("wb") as archive:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    archive.write(chunk)
    except OSError as error:
        temporary_output.unlink(missing_ok=True)
        raise FMODDownloadError(
            f"Failed to write FMOD archive ({type(error).__name__})."
        ) from error
    finally:
        response.close()

    if temporary_output.stat().st_size == 0:
        temporary_output.unlink(missing_ok=True)
        raise FMODDownloadError("Downloaded FMOD archive is empty.")

    temporary_output.replace(output)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download an authorized FMOD Studio API archive."
    )
    parser.add_argument(
        "--version",
        required=True,
        help="FMOD numeric version, e.g. 20220 for FMOD 2.02.20.",
    )
    parser.add_argument(
        "--platform",
        choices=PLATFORMS,
        required=True,
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
    )
    args = parser.parse_args()

    user = os.environ.get("FMOD_USER")
    password = os.environ.get("FMOD_PASSWORD")

    if not user or not password:
        print(
            "FMOD_USER and FMOD_PASSWORD must be configured.",
            file=sys.stderr,
        )
        return 2

    platform_directory, filename_suffix = PLATFORMS[args.platform]
    filename = f"fmodstudioapi{args.version}{filename_suffix}"
    print(f"Requested FMOD SDK: {filename} (platform directory: {platform_directory})", flush=True)

    try:
        token = authenticate(user, password)

        download_url = get_download_url(
            token=token,
            user=user,
            platform_directory=platform_directory,
            filename=filename,
        )

        download_archive(download_url, args.output)

    except FMODDownloadError as error:
        # Do not expose request URLs, account names, bearer tokens, signed
        # download URLs, or response bodies in CI logs.
        print(str(error), file=sys.stderr)
        return 1

    print(
        f"Downloaded FMOD {args.version} {args.platform} SDK archive."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

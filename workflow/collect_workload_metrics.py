#!/usr/bin/env python3

import argparse
import csv
import json
import subprocess
from pathlib import Path


def collect_job_metrics(instance_job_path, jobs):
    """
    Collect metrics for all workload jobs inside a Flux instance
    using a single Flux proxy invocation.
    """

    job_ids = [job["jobid"] for job in jobs]

    commands = []

    for job_id in job_ids:
        commands.append(
            f'echo "JOB:{job_id}"; '
            f'flux job info "{job_id}" eventlog'
        )

    command = "; ".join(commands)

    output = subprocess.check_output(
        [
            "flux",
            "proxy",
            instance_job_path,
            "bash",
            "-c",
            f"'{command}'",
        ],
        text=True,
    )

    # -------------------------------------------------------------------------
    # Split output into eventlogs for individual jobs

    eventlogs = {}
    current_job_id = None

    for line in output.splitlines():

        if line.startswith("JOB:"):
            current_job_id = line.removeprefix("JOB:")
            eventlogs[current_job_id] = []
            continue

        if line.strip() and current_job_id is not None:
            eventlogs[current_job_id].append(
                json.loads(line)
            )

    # -------------------------------------------------------------------------
    # Extract metrics

    metrics = {}

    for job_id, eventlog in eventlogs.items():

        times = {}

        for event in eventlog:
            times[event["name"]] = event["timestamp"]

        finish = next(
            (
                event for event in eventlog
                if event["name"] == "finish"
            ),
            None,
        )

        metrics[job_id] = {
            "submit_time": times.get("submit"),
            "alloc_time": times.get("alloc"),
            "start_time": times.get("start"),
            "finish_time": times.get("finish"),
            "clean_time": times.get("clean"),
            "exit_status":
                finish["context"]["status"]
                if finish is not None
                else None,
        }

    return metrics


# -----------------------------------------------------------------------------
def main():

    parser = argparse.ArgumentParser()

    parser.add_argument("instance_job_path")
    parser.add_argument("jobids_csv", type=Path)
    parser.add_argument("output_csv", type=Path)

    args = parser.parse_args()

    # -------------------------------------------------------------------------
    # Read jobs

    with open(args.jobids_csv) as f:
        jobs = list(csv.DictReader(f))

    if not jobs:
        return

    # -------------------------------------------------------------------------
    # Collect all job metrics through one Flux proxy

    metrics = collect_job_metrics(
        args.instance_job_path,
        jobs,
    )

    # -------------------------------------------------------------------------
    # Combine original job information with collected metrics

    rows = []

    for job in jobs:

        row = dict(job)
        row.update(metrics[job["jobid"]])
        rows.append(row)

    # -------------------------------------------------------------------------
    # Write output

    write_header = (
        not args.output_csv.exists()
        or args.output_csv.stat().st_size == 0
    )

    with open(args.output_csv, "a", newline="") as f:

        writer = csv.DictWriter(
            f,
            fieldnames=rows[0].keys(),
        )

        if write_header:
            writer.writeheader()

        writer.writerows(rows)


if __name__ == "__main__":
    main()
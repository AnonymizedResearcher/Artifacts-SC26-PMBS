#!/usr/bin/env python3

import argparse
import csv
import json
import subprocess
from pathlib import Path


# -----------------------------------------------------------------------------
# Helpers
def run(cmd):
    """Run a command and return stdout."""
    return subprocess.check_output(cmd, text=True)


def parse_eventlog(eventlog):
    """Parse a Flux eventlog into metrics."""

    # Eventlog is a string and contains empty lines between the JSON strings
    events = [
        json.loads(line)
        for line in eventlog.splitlines()
        if line.strip()
    ]

    times = {}
    exit_status = None

    for event in events:

        times[event['name']] = event['timestamp']

        if event['name'] == 'finish':
            exit_status = event['context']['status']

    return {
        'submit_time': times.get('submit'),
        'alloc_time': times.get('alloc'),
        'start_time': times.get('start'),
        'finish_time': times.get('finish'),
        'clean_time': times.get('clean'),
        'exit_status': exit_status,
    }


# -----------------------------------------------------------------------------
def collect_instance_job_metrics(jobid, parent_path = None):
    """Collect metrics for a single instance job."""

    if parent_path is None:   
        cmd_vec = ['flux','job','info',jobid,'eventlog']
    else:
        cmd_vec = ['flux','proxy',parent_path,'flux','job','info',jobid,'eventlog']

    return parse_eventlog(run(cmd_vec))


# -----------------------------------------------------------------------------
def collect_instance_metrics(hierarchy_file, level, output_file):

    hierarchy = json.loads(hierarchy_file.read_text())

    rows = []

    print(f'Collecting metrics for instance level {level}')

    instance = hierarchy['instance_level'][str(level)]
    parent = hierarchy['instance_level'][str(level - 1)]
    parent_path = parent['job_instance_path'] \
        if len(parent.get('job_instance_path', '')) > 0 else None

    row = {}

    row['instance_level'] = level

    # Keep hierarchy information
    row.update(instance)

    # Collect Flux metrics
    row.update(
        collect_instance_job_metrics(
            instance['job_instance_id'],
            parent_path
        )
    )

    rows.append(row)

    if rows:

        file_exists = output_file.exists()

        with open(output_file, "a", newline="") as f:

            writer = csv.DictWriter(
                f,
                fieldnames=rows[0].keys()
            )

            if not file_exists:
                writer.writeheader()

            writer.writerows(rows)


# -----------------------------------------------------------------------------
def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('hierarchy_json', type=Path)
    parser.add_argument('output_csv', type=Path)
    parser.add_argument('level', type=int)

    args = parser.parse_args()

    collect_instance_metrics(
        args.hierarchy_json,
        args.level,
        args.output_csv,
    )


# -----------------------------------------------------------------------------
if __name__ == '__main__':
    main()
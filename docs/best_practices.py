#!/usr/bin/python3
# Download JSON data from www.bestpractices.dev and analyze it.

# Since the JSON data is paged, we simply download each page in turn.
# This is written to be simple code; it loads the entire dataset into memory.
# It stores downloaded results in a file; erase the file to force the
# program to re-download the data.
# This example counts projects using the R programming language.
# Modify this example for whatever analysis you want to do.

# Copyright 2018, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

import os, sys, re, json, time, urllib
from urllib.request import urlopen

# File for storing cached value
cached_filename = 'projects.json'

# This is the base URL for project data.
base_url = 'https://www.bestpractices.dev/' + cached_filename

# Retrieve paged JSON data
def retrieve_data():
    retrieved_dataset = []
    page_number = 1
    while True:
        url = base_url + '?page=' + str(page_number)
        page_string = urlopen(url).read()
        page_data = json.loads(page_string)
        print(page_number, file=sys.stderr)
        if len(page_data) == 0:
            break
        retrieved_dataset += page_data
        page_number += 1
        time.sleep(1) # Add delay to avoid hitting rate limits
    return retrieved_dataset

# Load JSON data (from a file if possible, else it's retrieved and saved)
def load_data():
    if os.path.exists(cached_filename):
        print('Loading existing file: %s' % cached_filename, file=sys.stderr)
        f = open(cached_filename, 'r')
        return json.load(f)
    else:
        print('Retrieving data', file=sys.stderr)
        retrieved_dataset = retrieve_data()
        # Save data into file so we don't need to retrieve later
        print('Saving data to file: %s' % cached_filename, file=sys.stderr)
        f = open(cached_filename, 'w')
        json.dump(retrieved_dataset, f)
        return retrieved_dataset

#
# Load the JSON data by calling load_data()
#

json_dataset = load_data()

# Now json_dataset has complete set of data.  Print a count.
print('Number of projects = ', len(json_dataset))

# Now do some sample analysis.  Example analysis:
# Count projects saying they use the R programming language.
re_split_list = re.compile(r' *, *')
r_projects = 0
for project in json_dataset:
    if project['implementation_languages']:
        langs = re.split(re_split_list, project['implementation_languages'])
        if 'R' in langs: r_projects += 1
print('R projects =', r_projects)

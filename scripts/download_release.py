#!/usr/bin/env python3

import requests
import threading
import os.path
import argparse

base_url = 'https://github.com/BYU-ODH/'
api_base_url = 'https://api.github.com/repos/BYU-ODH/%s/releases'
repos = [
    'yvideojs',
    'EditorWidgets',
    'subtitle-timeline-editor',
    'TimedText',
    'yvideo-client'
]

class Worker(threading.Thread):
    def __init__(self, repo, authentication_query, production):
        threading.Thread.__init__(self)
        self.repo = repo
        self.query_string = '?access_token=%s' % authentication_query if authentication_query is not None else ''
        self.production = production

    def get_latest(self, releases):
        version = ''
        latest = None
        for rel in releases:
            # in production mode, prerelease must be false.
            # in staging, it doesn't matter what prerelease is, we just
            # want the latest release/prerelease
            suitable_for_our_needs = ((self.production and rel['prerelease'] is False) or not self.production)
            if suitable_for_our_needs and len(rel['assets']) == 1 and rel['tag_name'] > version:
                version = rel['tag_name']
                latest = rel
        return latest

    def write_release(self, filename, stream):
        with open(filename, 'wb') as f:
            for chunk in stream.iter_content(chunk_size=1024):
                if chunk: # filter out keep-alive new chunks
                    f.write(chunk)

    def request_file_stream(self, url):
        download_request = requests.get(url, stream=True)
        if download_request.status_code == 302:
            download_request = requests.get(download_request.headers['Location'], stream=True)
        return download_request

    def run(self):
        release_response = requests.get(api_base_url % self.repo + self.query_string)
        if release_response.status_code == 200:
            releases = release_response.json()
            latest = self.get_latest(releases)
            if latest:
                release_url = latest['assets'][0]['browser_download_url']
                filename = self.repo + '-' + latest['assets'][0]['name']
                if not os.path.isfile(filename):
                    stream = self.request_file_stream(release_url)
                    if stream.status_code == 200:
                        self.write_release(filename, stream)
                print(filename)

def parse_options():
    parser = argparse.ArgumentParser(prog='download_release.py', description='Downloads the latest releases for yvideo dependencies', add_help=True)
    parser.add_argument('-p', '--production', action='store_true', help='Whether to download production or beta code')
    parser.add_argument('-a', '--access_token', action='store', help='token used for authorization')
    return parser.parse_args()

def download():
    args = parse_options()
    workers = []
    for x in range(0, len(repos)):
        workers.append(Worker(repos[x], args.access_token, args.production))
        workers[x].start()

    for x in range(0, len(repos)):
        workers[x].join()

if __name__ == "__main__":
    download()


#!/usr/bin/env python3

import requests
import threading
import sys
import os.path

base_url = 'https://github.com/BYU-ODH/'
api_base_url = 'https://api.github.com/repos/BYU-ODH/%s/releases'
production = True
repos = [
    'yvideojs',
    'EditorWidgets',
    'subtitle-timeline-editor',
    'TimedText',
    'yvideo-client'
]

class Worker(threading.Thread):
    def __init__(self, repo):
        threading.Thread.__init__(self)
        self.repo = repo

    def get_latest(self, releases):
        version = ''
        latest = None
        for rel in releases:
            # in production mode, prerelease must be false.
            # in staging, it doesn't matter what prerelease is, we just
            # want the latest release/prerelease
            suitable_for_our_needs = ((production and rel['prerelease'] is False) or not production)
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
        release_response = requests.get(api_base_url % self.repo)
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

def download():
    workers = []
    for x in range(0, len(repos)):
        workers.append(Worker(repos[x]))
        workers[x].start()

    for x in range(0, len(repos)):
        workers[x].join()

if len(sys.argv) > 1:
    branch = sys.argv[1]
    if branch != 'master':
        production = True

if __name__ == "__main__":
    download(production)


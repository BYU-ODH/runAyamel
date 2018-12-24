#!/usr/bin/env python3

import requests
import threading
import sys

base_url = 'https://github.com/BYU-ODH/'
api_base_url = 'https://api.github.com/repos/BYU-ODH/%s/releases'
prerelease = False
repos = [
    'yvideojs',
    'EditorWidgets',
    'subtitle-timeline-editor',
    'TimedText'
]

class Worker(threading.Thread):
    def __init__(self, repo):
        threading.Thread.__init__(self)
        self.repo = repo

    def run(self):
        release_response = requests.get(api_base_url % self.repo)
        if release_response.status_code == 200:
            releases = release_response.json()
            release = ''
            for rel in releases:
                if rel['prerelease'] == prerelease and len(rel['assets']) == 1:
                    release = rel['assets'][0]['browser_download_url']
                    filename = self.repo + '-' + rel['assets'][0]['name']
                    download_request = requests.get(release, stream=True)
                    if download_request.status_code == 302:
                        print("Redirecting to %s" % download_request.headers['Location'])
                        download_request = requests.get(download_request.headers['Location'], stream=True)
                    with open(filename, 'wb') as f:
                        for chunk in download_request.iter_content(chunk_size=1024):
                            if chunk: # filter out keep-alive new chunks
                                f.write(chunk)
                    print(filename)
                    break

def download(prerelease):
    workers = []
    for x in range(0, 4):
        workers.append(Worker(repos[x]))
        workers[x].start()

    for x in range(0, 4):
        workers[x].join()

if len(sys.argv) > 1:
    branch = sys.argv[1]
    if branch != 'master':
        prerelease = True

download(prerelease)

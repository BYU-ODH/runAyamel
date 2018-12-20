#!/usr/bin/env python3

import requests
import threading

base_url = 'https://github.com/BYU-ODH/'
api_base_url = 'https://api.github.com/repos/BYU-ODH/%s/releases'
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
            if len(releases) > 0:
                assets = releases[0]['assets']
                if len(assets) > 0:
                    release = assets[0]['browser_download_url']
                    filename = self.repo + '-' + assets[0]['name']
                    download_request = requests.get(release, stream=True)
                    with open(self.repo+'-'+filename, 'wb') as f:
                        for chunk in download_request.iter_content(chunk_size=1024): 
                            if chunk: # filter out keep-alive new chunks
                                f.write(chunk)
                    print(filename)

workers = []
for x in range(0, 4):
    workers.append(Worker(repos[x]))
    workers[x].start()

for x in range(0, 4):
    workers[x].join()

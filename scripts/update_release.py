#!/usr/bin/env python3

import requests
import sys
import argparse

class UpdateRelease():
    def __init__(self, repo, list_url, edit_url):
        self.repo = repo
        self.list_url = list_url
        self.edit_url = edit_url
        patch_base_url = 'https://api.github.com/repos/BYU-ODH/%s/releases/%s?access_token=%s'

    def get_latest(self, releases):
        version = ''
        latest = None
        for rel in releases:
            if rel['tag_name'] > version:
                version = rel['tag_name']
                latest = rel
        return latest

    def upgrade_prerelease(self):
        release_response = requests.get(self.list_url)
        if release_response.status_code == 200:
            releases = release_response.json()
            latest = self.get_latest(releases)
            if latest['prerelease'] == False:
                data = {
                    'tag_name': latest['tag_name'],
                    'target_commitish': latest['target_commitish'],
                    'name': latest['name'],
                    'draft': False,
                    'prerelease': False
                }
                patch_response = requests.patch(self.edit_url % latest['id'], json=data)
                if patch_response.status_code == 200:
                    return True
                else:
                    return False
            else:
                return True
        else:
            return False

def parse_options():
    parser = argparse.ArgumentParser(prog='update_release.py', description='Changes a repo\'s latest pre-release to a full release.', add_help=True)
    parser.add_argument('repository', action='store', help='Target repository')
    parser.add_argument('access_token', action='store', help='Token used for authorization')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_options()
    list_base = 'https://api.github.com/repos/BYU-ODH/%s/releases?access_token=%s'
    edit_base = 'https://api.github.com/repos/BYU-ODH/%s/releases/%%s?access_token=%s'
    list_url = list_base % (args.repository, args.access_token)
    edit_url = edit_base % (args.repository, args.access_token)
    if UpdateRelease(args.repository, list_url, edit_url).upgrade_prerelease():
        print("Updated Release")
        sys.exit(0)
    else:
        print("Failed to Update Release")
        sys.exit(1)


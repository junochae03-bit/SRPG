"""Explicit output version; patch builds never replace a previous package."""
import argparse,re
parser=argparse.ArgumentParser()
parser.add_argument('--version',default='V0.6')
VERSION=parser.parse_args().version
if not re.fullmatch(r'V\d+\.\d+(?:\.\d+)?',VERSION):parser.error('Expected V0.1.1 style version')
KEY=VERSION.lower().replace('.','')

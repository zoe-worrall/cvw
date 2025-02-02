#!/usr/bin/env python3
import sys
import re

def usage():
    print("Usage: ./renumber.py <input xdc file> <output xdc file>")

def main(args):
    if (len(args) != 2):
        usage()
        exit()

    probenum = 0
    countLines = 1
        
    with open(args[0],'r') as xdcfile, open(args[1], 'w') as outfile:
        Lines = xdcfile.readlines()
        for line in Lines:
            t = re.sub("probe[0-9]+", f"probe{probenum}",line)
            
            if line.find("probe") >= 0:
                countLines = countLines + 1
                
            if countLines == 4:
                countLines = 0
                probenum = probenum + 1

            outfile.write(t)



if __name__ == '__main__':
    main(sys.argv[1:])

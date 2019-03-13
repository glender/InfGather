#! /bin/python
__author__ = "donutsThatsHowWeGetAnts"
__copyright__ = "Copyright (c) 2018 donutsThatsHowWeGetAnts"
__credits__ = [ "donutsThatsHowWeGetAnts" ]
__license__ = "MIT"
__version__ = "0.1"
__maintainer__ = "donutsThatsHowWeGetAnts"
__email__ = "None"
__status__ = "Production"

import multiprocessing
import subprocess
import os,sys

def ping( j, r ):
    DNULL = open(os.devnull, 'w')
    while True:
        ip = j.get()
        if ip is None:
            break
        try:
            subprocess.check_call(['ping', '-c1', ip], stdout=DNULL)
            r.put(ip)
        except:
            pass


def valid_ip(s):
    a = s.split('.')
    if len(a) != 3:
        return False
    for i in a:
        if not i.isdigit():
            return False
        octect = int(i)
        if octect < 0 or octect > 255:
            return False
    return True

if __name__ == "__main__":


    if valid_ip(sys.argv[1]):

        size = 255

        jobs = multiprocessing.Queue()
        results = multiprocessing.Queue()

        pool = [ multiprocessing.Process(target=ping, args=(jobs, results))
                for i in range(size) ]

        for p in pool:
            p.start()

        for i in range(1,255):
            jobs.put(sys.argv[1] + ".{0}".format(i))

        for p in pool:
            jobs.put(None)

        for p in pool:
            p.join()

            while not results.empty():
                ip = results.get()
                print(ip)
    else:
        print "Usage: " + sys.argv[0] + " IP"
        print "Example: " + sys.argv[0] + " 10.11.1"

#! /bin/python
__author__ = "donutsThatsHowWeGetAnts"
__copyright__ = "Copyright (c) 2018 donutsThatsHowWeGetAnts"
__credits__ = [ "donutsThatsHowWeGetAnts" ]
__license__ = "MIT"
__version__ = "0.1"
__maintainer__ = "donutsThatsHowWeGetAnts"
__email__ = "None"
__status__ = "Production"

from datetime import datetime
import os
import shlex
import subprocess
from time import sleep

class LogPing:

    def __init__(self, host, count=1, timeout_seconds=120, logfile="ping_log.txt"):
        self.host = host
        self.count = count
        self.timeout_seconds = timeout_seconds
        self.logfile = logfile

        self.output_blackhole = open(os.devnull, 'wb')


    def _command(self):
        command_string = "ping -c {count} -t {timeout} {host}".format(
                count=self.count, 
                timeout=self.timeout_seconds,
                host=self.host
            )

        try: 
            # we don't actually care about the output, just the return code, 
            # so trash the output. result == 0 on success
            result = subprocess.check_call(
                    shlex.split(command_string), 
                    stdout=self.output_blackhole, 
                    stderr=subprocess.STDOUT
                )
        except subprocess.CalledProcessError:
            # if here, that means that the host couldn't be reached for some reason.
            result = -1

        return result

    def run(self):
        ping_command_result = self._command()

        if ping_command_result == 0:
            status = "OK"
        else:
            status = "BROKEN"

        # The time won't be exact, but close enough
        message = "{status} : {time} : {host}\n".format(
                status=status, 
                time=datetime.utcnow().strftime("%Y-%m-%d_%T"), 
                host=self.host
            )

        # open file in a context manager for writing, creating if not exists
        # using a+ so that we append to the end of the last line.
        with open(self.logfile, 'a+') as f:
            f.write(message)

if __name__ == "__main__":
    while True:
        ping_instance = LogPing("172.16.1.100").run()
        sleep(1)

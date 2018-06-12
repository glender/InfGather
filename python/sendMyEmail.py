#! /bin/python
__author__ = "glender"
__copyright__ = "Copyright (c) 2018 glender"
__credits__ = [ "glender" ]
__license__ = "MIT"
__version__ = "0.1"
__maintainer__ = "glender"
__email__ = "None"
__status__ = "Production"

# argument parser
import optparse

# Import smtplib for the actual sending function
import smtplib

parser = optparse.OptionParser()

# To email address
parser.add_option('-t', '--to',
    action="store", dest="to",
    help="To email address", default="attacker@victim.com")

# From email address
parser.add_option('-f', '--from',
    action="store", dest="fromA",
    help="From email address", default="attacker@victim.com")

# Server to send to
parser.add_option('-s', '--server',
    action="store", dest="server",
    help="Server, SMTP mail relay", default="127.0.0.1")

# Port to send to
parser.add_option('-p', '--port',
    action="store", dest="port",
    help="Port to send to, default is 25", default="25")

# Subject of the message
parser.add_option('-u', '--subject',
    action="store", dest="subject",
    help="Subject of the email", default="Important!")

# Body/Content of the message
parser.add_option('-m', '--message',
    action="store", dest="message",
    help="Content of the email, read from a file. This should be HTML format", default="We have delivered the information!")

# Get the arguments
options, args = parser.parse_args()

# Import the email modules we'll need
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

msg = MIMEMultipart('alternative')
msg['Subject'] = options.subject
msg['From'] = options.fromA
msg['To'] = options.to

# If the user supplied a file to read, read it as the message content/body
with open(options.message, 'rb') as fp:
    # Create the content/body for the email
    msg.attach(MIMEText(fp.read(), 'html'))

# Send the message via our own SMTP server
s = smtplib.SMTP(options.server, options.port)
s.sendmail(options.fromA, [options.to], msg.as_string())
s.quit()
print 'Done!'

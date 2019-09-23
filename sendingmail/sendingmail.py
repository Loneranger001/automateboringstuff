import os
import smtplib, ssl

"""
Sending mail using SSL 
"""

smtp_server = 'smtp.gmail.com'
port = 465
# Password1$1

# sender = os.getenv('smtp_server')
sender = 'myownpythondeveloper@gmail.com'
print(sender)
receiver = 'asfkol@gmail.com'
password = input('Enter your password : ')
message = """\
Subject: Hi There!
From: {}
To: {}
This message was sent from Python! 

Please do not reply to this email.

""".format(sender, receiver)

# create a context, create default context
context = ssl.create_default_context()

with smtplib.SMTP_SSL(smtp_server, port, context=context) as server:
    server.login(sender, password)
    server.sendmail(sender, receiver, message)
    print('It worked!')

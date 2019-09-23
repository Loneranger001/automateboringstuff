import os
import smtplib, ssl

"""
Sending mail using SSL 
"""

smtp_server = 'smtp.gmail.com'
port = 465
# Password1$1

sender = 'myownpythondeveloper@gmail.com'
receiver = 'asfkol@gmail.com'
password = input('Enter your password : ')
message = """\
Subject: Hi There!

This message was sent from Python!

"""

# create a context, create default context
context = ssl.create_default_context()

with smtplib.SMTP_SSL(smtp_server, port, context=context) as server:
    server.login(sender, password)
    print('It worked!')

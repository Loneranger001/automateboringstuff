import os
import smtplib, ssl

smtp_server = 'smtp.gmail.com'
port = 465
# Password1$

sender = 'myownpythondeveloper@gmail.com'
password = input('Enter your password : ')
# create a context, create default context
context = ssl.create_default_context()

with smtplib.SMTP_SSL(smtp_server, port, context=context) as server:
    server.login(sender, password)
    print('It worked!')

import os
import smtplib, ssl

smtp_server = 'smtp.gmail.com'
# 587 for TLS encryption
port = 587

sender = 'myownpythondeveloper@gmail.com'
password = input('Please enter your password: ')
context = ssl.create_default_context()

try:
    server = smtplib.SMTP(smtp_server, port)
    # testing the server
    server.ehlo()
    # upgrade the connection or encrypt the connection
    server.starttls(context=context)
    server.ehlo()
    server.login(sender, password)
    print('It worked!')
except Exception as e:
    print(e)
finally:
    server.quit() # no matter what happens close the connection







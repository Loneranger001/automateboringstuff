import os
import smtplib, ssl

smtp_server = 'smtp.gmail.com'
port = 465

sender = ''
password = input('Enter your password : ')
# create a context
context = ssl.create_default_context()


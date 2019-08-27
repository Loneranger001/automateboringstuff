import re
message = 'I have 2 numbers, you can call me either on 7003305607 or 967-4796-5536'
phoneNumReg = re.compile(r'\d{3}-?\d{4}-?\d{4}|\d{10}')
print(phoneNumReg.findall(message)[0])
print(phoneNumReg.findall(message)[1])

'''
\d - numeric digit from 0-9
\D any character that is  non-numeric i.e. 0-9


'''

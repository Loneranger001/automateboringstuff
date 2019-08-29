import re
message = 'I have 2 numbers, you can call me either on 7003305607 or 967-4796-5536'
phoneNumReg = re.compile(r'\d{3}-?\d{4}-?\d{4}|\d{10}')
print(phoneNumReg.findall(message)[0])
print(phoneNumReg.findall(message)[1])

'''
\d - numeric digit from 0-9
\D any character that is  non-numeric i.e. 0-9
'''

# The dot character
noNewlineRegex = re.compile(r'.*')  # this will match everything except newline
mo = noNewlineRegex.search('Serve the public trust.\nProtect the innocent.\nUphold the law.')

print(mo.group())

# remember the term DOTALL
# The dot character which will match newline
noNewlineRegex = re.compile(r'.*', re.DOTALL)  # this will match everything
mo = noNewlineRegex.search('Serve the public trust.\nProtect the innocent.\nUphold the law.')

print(mo.group())

regex1 = re.compile('ROBOCOP', re.IGNORECASE)
regex2 = re.compile('robocop', re.IGNORECASE)
mo=regex1.findall(' ROBOCOP or robocop')
print(mo)

# replace using sub()
agentNamesRegex = re.compile(r'Agent (\w)\w*')
changedString = agentNamesRegex.sub(r'\1****', 'Agent Alice told Agent Carol that Agent '
                                                'Eve knew Agent Bob was a double agent.')
print(changedString)
# 
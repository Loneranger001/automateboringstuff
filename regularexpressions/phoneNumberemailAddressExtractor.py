import pyperclip
import re
# phoneNumRegex = re.compile(r'''(
# (\d{3}|\(\d{3}\))?      # area code, 0 or more occurance
# (\s|-|\.)?              # separator
# \d{3}                   # first 3 digits
# (\s|-|\.)?              # separator
# \d{4}                   # next 4 digits
# (\s*(ext|x|ext.)\s*\d{2,5})? #extension
# )''', re.VERBOSE)
phoneNumRegex = re.compile(r'''
(
  \d{3} #
   -?   # optional dash
  \d{3}
  -?    # optional dash
  \d{4}
)
''', re.VERBOSE)

# matches = phoneNumRegex.findall('My numbers 7003305607 or 700-330-5607')
# print(matches)

emailRegex = re.compile(r'''(
[A-Za-z0-9._%+-]+   # username
@                   #
[a-zA-Z0-9._]+      # domain name
(\.[A-Za-z]{2,4})   # dot-something
)
''', re.VERBOSE)
#
#
# matches = emailRegex.findall('My numbers 7003305607 or 700-330-5607, my 2 email addresses are asfko155l@gmail.com or onetechgeek88@gmail.com')
# print(matches)


matches = []
# Find matches in the clipBoard, paste the clipBoard content onto a variable.
text = str(pyperclip.paste())
#
for nums in phoneNumRegex.findall(text):
    matches.append(nums)
# print(matches)
for text in emailRegex.findall(text):
    matches.append(text[0])
#
print(matches)

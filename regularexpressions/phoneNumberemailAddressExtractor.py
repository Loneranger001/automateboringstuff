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
  (\d{3})
  (-?)
  (\d{3})
  (-)?
  (\d{4})
)
''', re.VERBOSE)

matches = phoneNumRegex.search('My numbers 7003305607 or 700-330-5607')
print(matches)

# # 345/(456)
# 7003305607
# 07003305607
# +91 7003305607



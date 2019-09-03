import os

# join command
myFiles=['accounts.txt', 'details.csv', 'invite.docx']
currentDir= os.getcwd()
for file in myFiles:
    print(os.path.join(currentDir, file))

print(os.path.join('usr', 'bin', 'spam'))
# relative and absolute path
print(os.path.abspath('.'))
print(os.path.isabs('.'))
print(os.path.isabs(os.path.abspath('.')))
print(os.path.abspath('.\\regularexpressions'))

# split base name and directory name
path = 'C:\\Windows\\System32\\calc.exe'
print(os.path.basename(path))
print(os.path.dirname(path))
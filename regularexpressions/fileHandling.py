import os
import sys
import getpass

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
print('-'.join(('Complete Path', os.path.splitext(path)[0])))
print(os.path.splitext(path)[0])
# print(os.path.dirname(path))

# creating directories
print(os.path.abspath(os.curdir))
# os.makedirs('.\\dir1\\dir2')
try:
    # os.rmdir('.\\dir1')
    # os.rmdir('.\\files')
    None
except FileNotFoundError as e:
    print(e)


if os.path.exists('files'):
    print('Directory Exists!')
else:
    os.makedirs('files')
    print('Directory Created')

# list of files and sizes
for file in os.listdir():
    print('Size of the File <%s> is %f KB' % (file, os.path.getsize(file)/1024))
    if os.path.getsize(file) == 0:
        print('Zero Byte File '+file)

# check if a path exists
if os.path.exists('identifyFileWithPattern.py'):
    if os.path.isdir('identifyFileWithPattern.py'):
        print('This is a directory.')
    else:
        print('This is a file')

print(os.path.exists('D:\\'))
print(os.getcwd())
os.chdir('files')
print(os.getcwd())
# open file.
print(os.path.splitext(os.path.basename(sys.argv[0]))[0])
print(getpass.getuser())
